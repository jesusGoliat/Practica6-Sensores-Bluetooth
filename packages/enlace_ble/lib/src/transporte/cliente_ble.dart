/// Rol central: escanea, conecta y expone un transporte.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../protocolo/transporte_bytes.dart';
import 'constantes_ble.dart';
import 'estado_bluetooth.dart';
import 'permisos_ble.dart';
import 'transporte_ble.dart';

/// Dispositivo anunciando el servicio de la práctica.
class DispositivoEncontrado {
  /// Crea un resultado de escaneo.
  const DispositivoEncontrado({required this.id, required this.nombre, required this.rssi});

  /// Identificador estable durante la sesión (para [ClienteBle.conectar]).
  final String id;

  /// Nombre anunciado (`P6-<app>-<4hex>`), o vacío.
  final String nombre;

  /// Intensidad de señal en dBm.
  final int rssi;

  @override
  String toString() => 'DispositivoEncontrado($nombre, $id, $rssi dBm)';
}

/// Estado del cliente BLE.
enum EstadoCliente { inactivo, escaneando, conectando, conectado, error }

/// Central GATT de la Práctica 6 (invitado / emisor).
///
/// Ningún método lanza: los fallos se reflejan en [estadoActual] y
/// [mensajeError] (en español).
class ClienteBle {
  final _estado = StreamController<EstadoCliente>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, Peripheral> _encontrados = {};
  EstadoCliente _actual = EstadoCliente.inactivo;
  String? _error;
  CentralManager? _gestor;
  Peripheral? _periferico;
  TransporteBleInterno? _transporte;
  bool _liberado = false;
  int _escaneoActual = 0;

  /// Cambios de estado.
  Stream<EstadoCliente> get estado => _estado.stream;

  /// Estado actual.
  EstadoCliente get estadoActual => _actual;

  /// Último mensaje de error o motivo de desconexión, en español.
  String? get mensajeError => _error;

  /// Transporte activo, si hay conexión.
  TransporteBytes? get transporte => _transporte;

  void _poner(EstadoCliente e, [String? error]) {
    _actual = e;
    if (error != null) _error = error;
    if (!_estado.isClosed) _estado.add(e);
  }

  /// Escanea dispositivos con el servicio de la práctica durante [tiempo].
  /// Cada dispositivo se emite una vez. El stream se cierra al terminar o al
  /// cancelar la suscripción; si Bluetooth no está listo se cierra de inmediato
  /// y [mensajeError] explica el motivo.
  Stream<DispositivoEncontrado> escanear({Duration tiempo = const Duration(seconds: 10)}) {
    final id = ++_escaneoActual;
    late final StreamController<DispositivoEncontrado> c;
    StreamSubscription<DiscoveredEventArgs>? sub;
    Timer? temporizador;
    var terminado = false;

    Future<void> terminar() async {
      if (terminado) return;
      terminado = true;
      temporizador?.cancel();
      await sub?.cancel();
      try {
        await _gestor?.stopDiscovery();
      } catch (_) {}
      if (_actual == EstadoCliente.escaneando && id == _escaneoActual) {
        _poner(EstadoCliente.inactivo);
      }
      if (!c.isClosed) await c.close();
    }

    Future<void> arrancar() async {
      if (_liberado) return terminar();
      final bt = await PermisosBle.solicitar(RolBle.central);
      if (!bt.disponible) {
        _error = bt.mensaje;
        return terminar();
      }
      try {
        final g = _gestor ??= CentralManager();
        _encontrados.clear();
        final vistos = <String>{};
        sub = g.discovered.listen((e) {
          try {
            final ident = e.peripheral.uuid.toString();
            _encontrados[ident] = e.peripheral;
            if (!vistos.add(ident) || c.isClosed) return;
            c.add(DispositivoEncontrado(
              id: ident,
              nombre: e.advertisement.name ?? '',
              rssi: e.rssi,
            ));
          } catch (_) {}
        }, onError: (Object _) {});
        await g.startDiscovery(serviceUUIDs: [uuidServicio]);
        _poner(EstadoCliente.escaneando);
        temporizador = Timer(tiempo, () => unawaited(terminar()));
      } catch (e) {
        _error = 'No se pudo escanear por Bluetooth: $e';
        _poner(EstadoCliente.error);
        await terminar();
      }
    }

    c = StreamController<DispositivoEncontrado>(
      onListen: () => unawaited(arrancar()),
      onCancel: terminar,
    );
    return c.stream;
  }

  /// Conecta con un dispositivo de [escanear]. Devuelve el transporte o `null`
  /// si falló (consulte [mensajeError]).
  Future<TransporteBytes?> conectar(String id) async {
    if (_liberado) return null;
    if (_actual == EstadoCliente.conectando || _actual == EstadoCliente.conectado) {
      return _transporte;
    }
    _error = null;
    _poner(EstadoCliente.conectando);
    final bt = await PermisosBle.solicitar(RolBle.central);
    if (!bt.disponible) {
      _poner(EstadoCliente.error, bt.mensaje);
      return null;
    }
    Peripheral? p;
    try {
      final g = _gestor ??= CentralManager();
      try {
        await g.stopDiscovery();
      } catch (_) {}
      p = _encontrados[id] ?? await g.getPeripheral(_direccion(id));
      _periferico = p;
      _escuchar(g);

      await g.connect(p).timeout(const Duration(seconds: 15));
      if (Platform.isAndroid) {
        try {
          await g.requestMTU(p, mtu: 512);
        } catch (_) {
          // Se sigue con el MTU que haya.
        }
      }
      final servicios = await g.discoverGATT(p);
      GATTService? servicio;
      for (final s in servicios) {
        if (s.uuid == uuidServicio) servicio = s;
      }
      if (servicio == null) {
        throw 'el dispositivo no ofrece el servicio de la práctica';
      }
      GATTCharacteristic? rx, tx;
      for (final ch in servicio.characteristics) {
        if (ch.uuid == uuidRx) rx = ch;
        if (ch.uuid == uuidTx) tx = ch;
      }
      if (rx == null || tx == null) {
        throw 'faltan las características RX/TX del servicio';
      }
      final tipo = rx.properties.contains(GATTCharacteristicProperty.writeWithoutResponse)
          ? GATTCharacteristicWriteType.withoutResponse
          : GATTCharacteristicWriteType.withResponse;
      var largo = fragmentoPorDefecto;
      try {
        largo = ajustarFragmento(await g.getMaximumWriteLength(p, type: tipo));
      } catch (_) {}
      final periferico = p;
      final rxFinal = rx;
      final t = TransporteBleInterno(
        maxFragmento: largo,
        escribir: (datos) =>
            g.writeCharacteristic(periferico, rxFinal, value: datos, type: tipo),
        alCerrar: () async => desconectar(),
      );
      _transporte = t;
      await g.setCharacteristicNotifyState(p, tx, state: true);
      _poner(EstadoCliente.conectado);
      return t;
    } catch (e) {
      final viejo = _transporte;
      _transporte = null;
      viejo?.marcarDesconectado();
      await _cortar(p);
      _poner(EstadoCliente.error, 'No se pudo conectar por Bluetooth: $e');
      return null;
    }
  }

  void _escuchar(CentralManager g) {
    if (_subs.isNotEmpty) return;
    _subs.add(g.connectionStateChanged.listen((a) {
      if (a.peripheral == _periferico && a.state == ConnectionState.disconnected) {
        unawaited(_perdida('El otro dispositivo se desconectó.'));
      }
    }, onError: (Object _) {}));
    _subs.add(g.characteristicNotified.listen((a) {
      if (a.peripheral == _periferico && a.characteristic.uuid == uuidTx) {
        _transporte?.entregar(a.value);
      }
    }, onError: (Object _) {}));
    _subs.add(g.stateChanged.listen((a) {
      if (a.state != BluetoothLowEnergyState.poweredOn && _periferico != null) {
        unawaited(_perdida('Bluetooth dejó de estar disponible.'));
      }
    }, onError: (Object _) {}));
  }

  /// En Android el plugin identifica por dirección MAC; el id de escaneo la
  /// codifica en los últimos 12 hexadecimales.
  String _direccion(String id) {
    if (Platform.isAndroid && id.startsWith('00000000-0000-0000-0000-')) {
      final h = id.substring(id.length - 12).toUpperCase();
      return [for (var i = 0; i < 12; i += 2) h.substring(i, i + 2)].join(':');
    }
    return id;
  }

  Future<void> _perdida(String motivo) async {
    if (_periferico == null) return;
    final t = _transporte;
    _transporte = null;
    t?.marcarDesconectado();
    await _cortar(_periferico);
    _poner(EstadoCliente.inactivo, motivo);
  }

  Future<void> _cortar(Peripheral? p) async {
    _periferico = null;
    final g = _gestor;
    if (g != null && p != null) {
      try {
        await g.disconnect(p);
      } catch (_) {}
    }
  }

  /// Cierra la conexión. Idempotente.
  Future<void> desconectar() async {
    final t = _transporte;
    _transporte = null;
    t?.marcarDesconectado();
    if (_periferico != null) {
      await _cortar(_periferico);
    }
    if (_actual != EstadoCliente.inactivo) _poner(EstadoCliente.inactivo);
  }

  /// Libera todo; el objeto no se puede reutilizar.
  Future<void> dispose() async {
    if (_liberado) return;
    _escaneoActual++;
    await desconectar();
    _liberado = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _estado.close();
  }
}
