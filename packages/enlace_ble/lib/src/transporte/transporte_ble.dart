/// Transporte BLE común a ambos roles (uso interno).
library;

import 'dart:async';
import 'dart:typed_data';

import '../protocolo/errores.dart';
import '../protocolo/transporte_bytes.dart';

/// Implementación de [TransporteBytes] respaldada por funciones del rol.
class TransporteBleInterno implements TransporteBytes {
  TransporteBleInterno({
    required int maxFragmento,
    required Future<void> Function(Uint8List) escribir,
    required Future<void> Function() alCerrar,
  }) : _maxFragmento = maxFragmento, _escribir = escribir, _alCerrar = alCerrar; // ignore: prefer_initializing_formals

  int _maxFragmento;
  final Future<void> Function(Uint8List) _escribir;
  final Future<void> Function() _alCerrar;
  final _recibidos = StreamController<Uint8List>.broadcast();
  final _estado = StreamController<EstadoConexion>.broadcast();
  EstadoConexion _actual = EstadoConexion.conectado;
  Future<void> _cola = Future.value();

  @override
  int get maxFragmento => _maxFragmento;

  /// Actualiza el tamaño tras una renegociación de MTU.
  set maxFragmento(int valor) => _maxFragmento = valor;

  @override
  Stream<Uint8List> get recibidos => _recibidos.stream;

  @override
  Stream<EstadoConexion> get estado => _estado.stream;

  @override
  EstadoConexion get estadoActual => _actual;

  /// Entrega un fragmento recibido del par.
  void entregar(Uint8List datos) {
    if (_actual == EstadoConexion.conectado && !_recibidos.isClosed) {
      _recibidos.add(Uint8List.fromList(datos));
    }
  }

  @override
  Future<void> enviar(Uint8List fragmento) {
    if (_actual != EstadoConexion.conectado) {
      return Future.error(const ErrorEnlace('La conexión Bluetooth no está activa.'));
    }
    final tarea = _cola.then((_) async {
      if (_actual != EstadoConexion.conectado) {
        throw const ErrorEnlace('La conexión Bluetooth no está activa.');
      }
      try {
        await _escribir(fragmento);
      } on ErrorEnlace {
        rethrow;
      } catch (e) {
        throw ErrorEnlace('No se pudo enviar por Bluetooth: $e');
      }
    });
    _cola = tarea.catchError((_) {});
    return tarea;
  }

  /// Marca la conexión como perdida (sin llamar a [_alCerrar]).
  void marcarDesconectado() {
    if (_actual == EstadoConexion.desconectado) return;
    _actual = EstadoConexion.desconectado;
    if (!_estado.isClosed) _estado.add(EstadoConexion.desconectado);
  }

  @override
  Future<void> cerrar() async {
    final yaCerrado = _estado.isClosed;
    marcarDesconectado();
    if (yaCerrado) return;
    try {
      await _alCerrar();
    } catch (_) {}
    await _estado.close();
    await _recibidos.close();
  }
}
