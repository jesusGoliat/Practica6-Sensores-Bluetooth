/// Rol periférico: anuncia, acepta un central y expone un transporte.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../protocolo/transporte_bytes.dart';
import 'constantes_ble.dart';
import 'estado_bluetooth.dart';
import 'permisos_ble.dart';
import 'transporte_ble.dart';

/// Estado del servidor BLE.
enum EstadoServidor { detenido, iniciando, anunciando, conectado, error }

/// Periférico GATT de la Práctica 6 (anfitrión / receptor).
///
/// Ningún método lanza: los fallos se reflejan en [estadoActual] y
/// [mensajeError] (en español).
class ServidorBle {
  /// [app] identifica la aplicación en el nombre anunciado `P6-<app>-<4hex>`.
  ServidorBle({required String app, Random? azar})
    : app = _limpiar8(app),
      _sufijo = (azar ?? Random()).nextInt(0x10000);

  /// App anunciada (`juego`, `archivos` o `web`).
  final String app;
  final int _sufijo;

  /// Nombre visible `P6-<app>-<4hex>` con el que los centrales lo listan.
  String get nombreAnuncio => nombreVisible(app, _sufijo);

  static String _limpiar8(String app) {
    final limpio = app.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final corto = limpio.length > 8 ? limpio.substring(0, 8) : limpio;
    return corto.isEmpty ? 'app' : corto;
  }

  /// Android: datos de fabricante (no renombra el adaptador del teléfono).
  /// iOS: nombre local (CoreBluetooth no anuncia datos de fabricante).
  Advertisement _anuncio() {
    if (Platform.isAndroid) {
      return Advertisement(
        serviceUUIDs: [uuidServicio],
        manufacturerSpecificData: [
          ManufacturerSpecificData(
            id: idFabricantePruebas,
            data: Uint8List.fromList(datosFabricante(app, _sufijo)),
          ),
        ],
      );
    }
    return Advertisement(name: nombreAnuncio, serviceUUIDs: [uuidServicio]);
  }

  final _estado = StreamController<EstadoServidor>.broadcast();
  final _conexiones = StreamController<TransporteBytes>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  EstadoServidor _actual = EstadoServidor.detenido;
  String? _error;
  PeripheralManager? _gestor;
  GATTCharacteristic? _tx;
  Central? _central;
  TransporteBleInterno? _transporte;
  bool _liberado = false;

  /// Cambios de estado.
  Stream<EstadoServidor> get estado => _estado.stream;

  /// Estado actual.
  EstadoServidor get estadoActual => _actual;

  /// Último mensaje de error o motivo de desconexión, en español.
  String? get mensajeError => _error;

  /// Cada vez que un central queda aceptado se emite su transporte.
  Stream<TransporteBytes> get conexiones => _conexiones.stream;

  /// Transporte del central conectado, si existe.
  TransporteBytes? get transporte => _transporte;

  void _poner(EstadoServidor e, [String? error]) {
    _actual = e;
    if (error != null) _error = error;
    if (!_estado.isClosed) _estado.add(e);
  }

  /// Pide permisos, publica el servicio GATT y empieza a anunciar.
  /// Devuelve el estado de Bluetooth; solo `encendido` implica que se inició.
  Future<EstadoBluetooth> iniciar() async {
    if (_liberado) return EstadoBluetooth.desconocido;
    if (_actual == EstadoServidor.iniciando ||
        _actual == EstadoServidor.anunciando ||
        _actual == EstadoServidor.conectado) {
      return EstadoBluetooth.encendido;
    }
    _error = null;
    _poner(EstadoServidor.iniciando);
    final bt = await PermisosBle.solicitar(RolBle.periferico);
    if (!bt.disponible) {
      _poner(EstadoServidor.detenido, bt.mensaje);
      return bt;
    }
    try {
      final g = _gestor ??= PeripheralManager();
      _escuchar(g);
      await g.removeAllServices();
      final rx = GATTCharacteristic.mutable(
        uuid: uuidRx,
        properties: [
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
        ],
        permissions: [GATTCharacteristicPermission.write],
        descriptors: [],
      );
      final tx = GATTCharacteristic.mutable(
        uuid: uuidTx,
        properties: [GATTCharacteristicProperty.notify],
        permissions: [GATTCharacteristicPermission.read],
        descriptors: [],
      );
      _tx = tx;
      await g.addService(
        GATTService(
          uuid: uuidServicio,
          isPrimary: true,
          includedServices: [],
          characteristics: [rx, tx],
        ),
      );
      await g.startAdvertising(_anuncio());
      _poner(EstadoServidor.anunciando);
      return EstadoBluetooth.encendido;
    } catch (e) {
      await _limpiar();
      _poner(EstadoServidor.error, 'No se pudo anunciar por Bluetooth: $e');
      return EstadoBluetooth.encendido;
    }
  }

  void _escuchar(PeripheralManager g) {
    if (_subs.isNotEmpty) return;
    void ante<T>(Stream<T> s, void Function(T) f) {
      _subs.add(
        s.listen((x) {
          try {
            f(x);
          } catch (_) {}
        }, onError: (Object _) {}),
      );
    }

    ante(g.characteristicNotifyStateChanged, _alCambiarNotificacion);
    ante(g.characteristicWriteRequested, _alEscribir);
    ante(g.connectionStateChanged, (CentralConnectionStateChangedEventArgs a) {
      if (a.state == ConnectionState.disconnected && a.central == _central) {
        unawaited(_perdida('El otro dispositivo se desconectó.'));
      }
    });
    ante(g.mtuChanged, (CentralMTUChangedEventArgs a) {
      if (a.central == _central) {
        _transporte?.maxFragmento = ajustarFragmento(a.mtu - 3);
      }
    });
    ante(g.stateChanged, (BluetoothLowEnergyStateChangedEventArgs a) {
      if (a.state != BluetoothLowEnergyState.poweredOn &&
          _actual != EstadoServidor.detenido) {
        unawaited(_perdida('Bluetooth dejó de estar disponible.'));
      }
    });
  }

  void _alCambiarNotificacion(GATTCharacteristicNotifyStateChangedEventArgs a) {
    if (a.characteristic.uuid != uuidTx) return;
    if (a.state) {
      if (_central != null || _actual != EstadoServidor.anunciando) return;
      unawaited(_aceptar(a.central));
    } else if (a.central == _central) {
      unawaited(_perdida('El otro dispositivo dejó de escuchar.'));
    }
  }

  Future<void> _aceptar(Central central) async {
    final g = _gestor;
    final tx = _tx;
    if (g == null || tx == null) return;
    _central = central;
    var largo = fragmentoPorDefecto;
    try {
      largo = ajustarFragmento(await g.getMaximumNotifyLength(central));
    } catch (_) {}
    if (_central != central) return; // se perdió mientras tanto
    final t = TransporteBleInterno(
      maxFragmento: largo,
      escribir: (datos) => g.notifyCharacteristic(central, tx, value: datos),
      alCerrar: () async => detener(),
    );
    _transporte = t;
    try {
      await g.stopAdvertising();
    } catch (_) {}
    _poner(EstadoServidor.conectado);
    if (!_conexiones.isClosed) _conexiones.add(t);
  }

  void _alEscribir(GATTCharacteristicWriteRequestedEventArgs a) {
    final g = _gestor;
    if (g == null) return;
    final valido =
        a.characteristic.uuid == uuidRx &&
        a.central == _central &&
        a.request.offset == 0;
    unawaited(() async {
      try {
        if (valido) {
          await g.respondWriteRequest(a.request);
        } else {
          await g.respondWriteRequestWithError(
            a.request,
            error: a.request.offset != 0
                ? GATTError.invalidOffset
                : GATTError.writeNotPermitted,
          );
        }
      } catch (_) {}
    }());
    if (valido) _transporte?.entregar(a.request.value);
  }

  Future<void> _perdida(String motivo) async {
    if (_actual == EstadoServidor.detenido) return;
    await _limpiar();
    _poner(EstadoServidor.detenido, motivo);
  }

  Future<void> _limpiar() async {
    final g = _gestor;
    final central = _central;
    final t = _transporte;
    _central = null;
    _transporte = null;
    t?.marcarDesconectado();
    if (g != null) {
      try {
        await g.stopAdvertising();
      } catch (_) {}
      if (central != null) {
        try {
          await g.disconnect(central);
        } catch (_) {}
      }
      try {
        await g.removeAllServices();
      } catch (_) {}
    }
  }

  /// Deja de anunciar y desconecta al central. Idempotente.
  Future<void> detener() async {
    if (_actual == EstadoServidor.detenido) return;
    await _limpiar();
    _poner(EstadoServidor.detenido);
  }

  /// Libera todo; el objeto no se puede reutilizar.
  Future<void> dispose() async {
    if (_liberado) return;
    await detener();
    _liberado = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _estado.close();
    await _conexiones.close();
  }
}
