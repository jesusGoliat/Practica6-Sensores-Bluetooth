/// Transporte en memoria para pruebas.
library;

import 'dart:async';
import 'dart:typed_data';

import 'errores.dart';
import 'transporte_bytes.dart';

/// Extremo de un par conectado en memoria.
///
/// Permite perder o duplicar fragmentos y simular una desconexión.
class TransporteMemoria implements TransporteBytes {
  TransporteMemoria._(this.maxFragmento);

  /// Crea dos extremos conectados entre sí.
  static (TransporteMemoria, TransporteMemoria) par({int maxFragmento = 20}) {
    final a = TransporteMemoria._(maxFragmento);
    final b = TransporteMemoria._(maxFragmento);
    a._par = b;
    b._par = a;
    return (a, b);
  }

  @override
  final int maxFragmento;

  /// Si devuelve `true`, el fragmento saliente se pierde.
  /// Recibe el fragmento y su número de envío (desde 0) en este extremo.
  bool Function(Uint8List fragmento, int numero)? descartar;

  /// Si devuelve `true`, el fragmento saliente se entrega dos veces.
  bool Function(Uint8List fragmento, int numero)? duplicar;

  /// Cantidad de fragmentos que este extremo ha intentado enviar.
  int get enviados => _enviados;

  late final TransporteMemoria _par;
  final _recibidos = StreamController<Uint8List>.broadcast();
  final _estado = StreamController<EstadoConexion>.broadcast();
  EstadoConexion _actual = EstadoConexion.conectado;
  int _enviados = 0;

  @override
  Stream<Uint8List> get recibidos => _recibidos.stream;

  @override
  Stream<EstadoConexion> get estado => _estado.stream;

  @override
  EstadoConexion get estadoActual => _actual;

  @override
  Future<void> enviar(Uint8List fragmento) async {
    if (_actual != EstadoConexion.conectado) {
      throw const ErrorEnlace('La conexión en memoria está cerrada.');
    }
    final n = _enviados++;
    if (descartar?.call(fragmento, n) ?? false) return;
    final copias = (duplicar?.call(fragmento, n) ?? false) ? 2 : 1;
    for (var i = 0; i < copias; i++) {
      final copia = Uint8List.fromList(fragmento);
      scheduleMicrotask(() => _par._entregar(copia));
    }
  }

  void _entregar(Uint8List f) {
    if (_actual == EstadoConexion.conectado && !_recibidos.isClosed) {
      _recibidos.add(f);
    }
  }

  void _marcarDesconectado() {
    if (_actual == EstadoConexion.desconectado) return;
    _actual = EstadoConexion.desconectado;
    if (!_estado.isClosed) _estado.add(EstadoConexion.desconectado);
  }

  /// Simula la pérdida de la conexión en ambos extremos.
  void simularDesconexion() {
    _marcarDesconectado();
    _par._marcarDesconectado();
  }

  @override
  Future<void> cerrar() async {
    if (_estado.isClosed) return;
    _marcarDesconectado();
    _par._marcarDesconectado();
    await _estado.close();
    await _recibidos.close();
  }
}
