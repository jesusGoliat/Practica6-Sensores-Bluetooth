/// Enlace: fragmentación + sobres + ACK + duplicados sobre un transporte.
library;

import 'dart:async';
import 'dart:typed_data';

import 'control_duplicados.dart';
import 'errores.dart';
import 'fragmentacion.dart';
import 'sobre.dart';
import 'tipos.dart';
import 'transporte_bytes.dart';

/// Capa de enlace sobre un [TransporteBytes] ya conectado.
class Enlace {
  /// Crea el enlace y empieza a escuchar el transporte.
  ///
  /// [tiempoAck] y [reintentos] controlan el envío confiable (3 s, 3 reintentos
  /// por defecto). [reloj] se usa para vencer fragmentos incompletos.
  Enlace(
    this._transporte, {
    this.tiempoAck = const Duration(seconds: 3),
    this.reintentos = 3,
    Duration tiempoReensamblado = const Duration(seconds: 10),
    DateTime Function()? reloj,
    ControlDuplicados? duplicados,
  })  : _fragmentador = Fragmentador(_transporte.maxFragmento),
        _reensamblador = Reensamblador(tiempoLimite: tiempoReensamblado, reloj: reloj),
        _duplicados = duplicados ?? ControlDuplicados(),
        _estadoActual = _transporte.estadoActual {
    _subRecibidos = _transporte.recibidos.listen(_alRecibir, onError: (_) {});
    _subEstado = _transporte.estado.listen(_alCambiarEstado, onError: (_) {});
  }

  final TransporteBytes _transporte;

  /// Espera máxima por ACK en cada intento.
  final Duration tiempoAck;

  /// Reintentos tras el primer intento (total de intentos = reintentos + 1).
  final int reintentos;

  final Fragmentador _fragmentador;
  final Reensamblador _reensamblador;
  final ControlDuplicados _duplicados;

  final _mensajes = StreamController<Sobre>.broadcast();
  final _errores = StreamController<ErrorProtocolo>.broadcast();
  final _estado = StreamController<EstadoConexion>.broadcast();
  final Map<String, Completer<void>> _esperandoAck = {};
  final Map<String, int> _seqPorSesion = {};
  late final StreamSubscription<Uint8List> _subRecibidos;
  late final StreamSubscription<EstadoConexion> _subEstado;
  EstadoConexion _estadoActual;
  Future<void> _cola = Future.value();
  bool _cerrado = false;

  /// Mensajes recibidos, sin ACK y ya sin duplicados.
  Stream<Sobre> get mensajes => _mensajes.stream;

  /// Mensajes inválidos recibidos (formato, versión, fragmentos).
  Stream<ErrorProtocolo> get errores => _errores.stream;

  /// Cambios de estado de la conexión.
  Stream<EstadoConexion> get estado => _estado.stream;

  /// Estado actual de la conexión.
  EstadoConexion get estadoActual => _estadoActual;

  /// Transporte subyacente.
  TransporteBytes get transporte => _transporte;

  /// Envía un mensaje con `seq` automático por sesión.
  ///
  /// Si [confiable] es `null`, se decide por [TiposMensaje.esConfiable]. Un
  /// envío confiable espera el ACK y reintenta; lanza [ErrorEnlace] si no llega.
  /// Devuelve el [Sobre] enviado.
  Future<Sobre> enviar(
    String canal,
    String sesion,
    String tipo,
    Map<String, dynamic> datos, {
    bool? confiable,
  }) async {
    final espera = confiable ?? TiposMensaje.esConfiable(tipo);
    final seq = (_seqPorSesion[sesion] ?? 0) + 1;
    _seqPorSesion[sesion] = seq;
    final sobre = Sobre(canal: canal, sesion: sesion, seq: seq, tipo: tipo, datos: datos);
    await _enviarSobre(sobre, espera: espera);
    return sobre;
  }

  Future<void> _enviarSobre(Sobre sobre, {required bool espera}) async {
    _exigirActivo();
    final bytes = sobre.toBytes();
    if (bytes.length > maxMensaje) {
      throw ErrorEnlace('El mensaje (${bytes.length} B) excede 64 KiB.');
    }
    if (!espera) {
      await _enviarBytes(bytes);
      return;
    }
    final clave = _clave(sobre.canal, sobre.sesion, sobre.seq);
    final intentos = reintentos + 1;
    try {
      for (var i = 0; i < intentos; i++) {
        final c = Completer<void>();
        _esperandoAck[clave] = c;
        unawaited(c.future.catchError((Object _) {}));
        await _enviarBytes(bytes);
        try {
          await c.future.timeout(tiempoAck);
          return;
        } on TimeoutException {
          _exigirActivo();
        }
      }
      throw ErrorEnlace(
          'Sin confirmación (ACK) del mensaje ${sobre.tipo} tras $intentos intentos.');
    } finally {
      _esperandoAck.remove(clave);
    }
  }

  void _exigirActivo() {
    if (_cerrado) throw const ErrorEnlace('El enlace está cerrado.');
    if (_estadoActual != EstadoConexion.conectado) {
      throw const ErrorEnlace('No hay conexión con el otro dispositivo.');
    }
  }

  /// Envía todos los fragmentos de un mensaje de forma contigua.
  Future<void> _enviarBytes(Uint8List bytes) {
    final tarea = _cola.then((_) async {
      _exigirActivo();
      try {
        for (final f in _fragmentador.fragmentar(bytes)) {
          await _transporte.enviar(f);
        }
      } on ErrorProtocolo catch (e) {
        throw ErrorEnlace(e.mensaje);
      } on ErrorEnlace {
        rethrow;
      } catch (e) {
        throw ErrorEnlace('Fallo al enviar por el transporte: $e');
      }
    });
    _cola = tarea.catchError((_) {});
    return tarea;
  }

  static String _clave(String canal, String sesion, int seq) => '$canal/$sesion/$seq';

  void _alRecibir(Uint8List fragmento) {
    if (_cerrado) return;
    Uint8List? completo;
    try {
      completo = _reensamblador.agregar(fragmento);
    } on ErrorProtocolo catch (e) {
      _errores.add(e);
      return;
    }
    if (completo == null) return;
    final Sobre sobre;
    try {
      sobre = Sobre.fromBytes(completo);
    } on ErrorProtocolo catch (e) {
      _errores.add(e);
      if (e.codigo == 'version') _avisarError(e);
      return;
    }
    if (sobre.tipo == TiposMensaje.ack) {
      final c = _esperandoAck[_clave(sobre.canal, sobre.sesion, sobre.ack!)];
      if (c != null && !c.isCompleted) c.complete();
      return;
    }
    if (TiposMensaje.esConfiable(sobre.tipo)) _responderAck(sobre);
    if (_duplicados.esNuevo(sobre.canal, sobre.sesion, sobre.seq)) {
      _mensajes.add(sobre);
    }
  }

  void _responderAck(Sobre origen) {
    final ack = Sobre(
      canal: origen.canal,
      sesion: origen.sesion,
      seq: 0,
      tipo: TiposMensaje.ack,
      ack: origen.seq,
    );
    unawaited(_enviarBytes(ack.toBytes()).catchError((Object _) {}));
  }

  void _avisarError(ErrorProtocolo e) {
    final sobre = Sobre(
      canal: Canales.control,
      sesion: '00000000',
      seq: 0,
      tipo: TiposMensaje.error,
      datos: {'codigo': e.codigo, 'mensaje': e.mensaje},
    );
    unawaited(_enviarBytes(sobre.toBytes()).catchError((Object _) {}));
  }

  void _alCambiarEstado(EstadoConexion nuevo) {
    _estadoActual = nuevo;
    if (!_estado.isClosed) _estado.add(nuevo);
    if (nuevo == EstadoConexion.desconectado) {
      _reensamblador.reiniciar();
      for (final c in _esperandoAck.values.toList()) {
        if (!c.isCompleted) {
          c.completeError(const ErrorEnlace('Conexión perdida antes de recibir el ACK.'));
        }
      }
    }
  }

  /// Cierra el enlace y el transporte. Idempotente.
  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    for (final c in _esperandoAck.values.toList()) {
      if (!c.isCompleted) c.completeError(const ErrorEnlace('El enlace se cerró.'));
    }
    await _subRecibidos.cancel();
    await _subEstado.cancel();
    try {
      await _transporte.cerrar();
    } catch (_) {}
    await _mensajes.close();
    await _errores.close();
    await _estado.close();
  }
}
