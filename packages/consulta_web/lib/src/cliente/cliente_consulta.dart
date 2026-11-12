/// Cliente B: pide por Bluetooth, nunca hace HTTP.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:enlace_ble/enlace_ble.dart';

import '../dominio/cache_web.dart';
import '../dominio/codigos_web.dart';

/// De dónde viene lo mostrado.
enum OrigenRespuesta { red, cache }

/// Resultado de una consulta (éxito o error).
class Resultado {
  /// Crea un resultado.
  const Resultado({
    required this.url,
    this.origen,
    this.estado,
    this.tipo,
    this.texto,
    this.bytes,
    this.tamano,
    this.ms,
    this.urlFinal,
    this.fecha,
    this.error,
    this.codigoError,
    this.aviso,
  });

  final String url;

  /// `null` si fue un error sin datos.
  final OrigenRespuesta? origen;
  final int? estado;
  final String? tipo;
  final String? texto;
  final Uint8List? bytes;
  final int? tamano;
  final int? ms;
  final String? urlFinal;

  /// Fecha de la respuesta (de la caché si [origen] es `cache`).
  final DateTime? fecha;

  /// Mensaje de error (si no hay datos).
  final String? error;
  final String? codigoError;

  /// Explicación de por qué se usó la caché.
  final String? aviso;

  /// Hay datos que mostrar.
  bool get ok => error == null && origen != null;
}

class _FalloEnlace implements Exception {
  _FalloEnlace(this.mensaje);
  final String mensaje;
}

/// Lógica del cliente B.
class ClienteConsulta {
  /// [tiempoEspera] es el plazo total de una consulta (20 s).
  ClienteConsulta({
    required this.cache,
    this.tiempoEspera = const Duration(seconds: 20),
    Random? azar,
  }) : _azar = azar ?? Random.secure();

  final CacheWeb cache;
  final Duration tiempoEspera;
  final Random _azar;
  final String sesion = Sobre.nuevaSesion();

  Enlace? _enlace;
  StreamSubscription<Sobre>? _subMsg;
  StreamSubscription<EstadoConexion>? _subEstado;
  final Map<String, Completer<Sobre>> _pendientes = {};
  int _contador = 0;

  /// Hay enlace activo con A.
  bool get conectado => _enlace != null && _enlace!.estadoActual == EstadoConexion.conectado;

  /// Asocia (o quita con `null`) el enlace con A.
  void conectar(Enlace? enlace) {
    _subMsg?.cancel();
    _subEstado?.cancel();
    _enlace = enlace;
    if (enlace == null) {
      _fallarPendientes('Se perdió la conexión Bluetooth con A.');
      return;
    }
    _subMsg = enlace.mensajes.listen(_alMensaje);
    _subEstado = enlace.estado.listen((e) {
      if (e == EstadoConexion.desconectado) {
        _fallarPendientes('Se perdió la conexión Bluetooth con A.');
      }
    });
  }

  void _fallarPendientes(String m) {
    for (final c in _pendientes.values.toList()) {
      if (!c.isCompleted) c.completeError(_FalloEnlace(m));
    }
  }

  void _alMensaje(Sobre s) {
    if (s.canal != Canales.web) return;
    if (s.tipo != TiposMensaje.respuesta && s.tipo != TiposMensaje.errorWeb) return;
    final c = _pendientes[s.datos['req']];
    if (c == null || c.isCompleted) return; // tardía, duplicada o desconocida
    c.complete(s);
  }

  String _nuevoReq() {
    final r = List.generate(6, (_) => _azar.nextInt(16).toRadixString(16)).join();
    return 'r${(++_contador).toRadixString(16).padLeft(4, '0')}$r';
  }

  /// Consulta [url] a través de A; si no hay enlace o se agota, usa la caché.
  Future<Resultado> consultar(String url, {String? req}) async {
    url = url.trim();
    if (!conectado) return _sinEnlace(url, 'No hay conexión Bluetooth con A.');
    final id = req ?? _nuevoReq();
    final c = Completer<Sobre>();
    _pendientes[id] = c;
    final sw = Stopwatch()..start();
    try {
      _enlace!
          .enviar(Canales.web, sesion, TiposMensaje.peticion, {'req': id, 'url': url})
          .then<void>((_) {}, onError: (Object e) {
        if (!c.isCompleted) {
          c.completeError(_FalloEnlace(e is ErrorEnlace ? e.mensaje : 'Falló el envío: $e'));
        }
      });
      final s = await c.future.timeout(tiempoEspera);
      return await _interpretar(url, s, sw.elapsedMilliseconds);
    } on TimeoutException {
      return _sinEnlace(url, 'A no respondió en ${tiempoEspera.inSeconds} s.');
    } on _FalloEnlace catch (e) {
      return _sinEnlace(url, e.mensaje);
    } finally {
      // Req desconocida a partir de aquí: una respuesta tardía se ignora.
      _pendientes.remove(id);
    }
  }

  Future<Resultado> _interpretar(String url, Sobre s, int msTotal) async {
    final d = s.datos;
    if (s.tipo == TiposMensaje.errorWeb) {
      final cod = (d['codigo'] as String?) ?? 'desconocido';
      return Resultado(
        url: url,
        codigoError: cod,
        error: (d['mensaje'] as String?) ?? CodigosWeb.describir(cod),
      );
    }
    try {
      final estado = d['estado'] as int;
      final tipo = d['tipo'] as String;
      final texto = d['cuerpo'] as String?;
      final bytes = d['b64'] == null ? null : base64Decode(d['b64'] as String);
      if (texto == null && bytes == null) throw const FormatException('sin cuerpo');
      final fecha = DateTime.parse(d['fecha'] as String);
      final ms = d['ms'] as int?;
      final urlFinal = d['urlFinal'] as String?;
      if (estado >= 200 && estado < 300) {
        await cache.guardar(EntradaCache(
          url: url,
          tipo: tipo,
          estado: estado,
          fecha: fecha,
          texto: texto,
          bytes: bytes,
          urlFinal: urlFinal,
          ms: ms,
        ));
      }
      return Resultado(
        url: url,
        origen: OrigenRespuesta.red,
        estado: estado,
        tipo: tipo,
        texto: texto,
        bytes: bytes,
        tamano: (d['bytes'] as int?) ?? bytes?.length ?? texto!.length,
        ms: ms,
        urlFinal: urlFinal,
        fecha: fecha,
      );
    } catch (_) {
      return Resultado(
          url: url,
          codigoError: CodigosWeb.formato,
          error: 'La respuesta de A está mal formada.');
    }
  }

  Resultado _sinEnlace(String url, String motivo) {
    final e = cache.obtener(url);
    if (e == null) {
      return Resultado(url: url, codigoError: 'sin_enlace', error: '$motivo No hay copia en caché de esta URL.');
    }
    return resultadoDeCache(e, aviso: '$motivo Se muestra la copia guardada.');
  }

  /// Convierte una entrada de caché en resultado marcado como CACHÉ.
  static Resultado resultadoDeCache(EntradaCache e, {String? aviso}) => Resultado(
        url: e.url,
        origen: OrigenRespuesta.cache,
        estado: e.estado,
        tipo: e.tipo,
        texto: e.texto,
        bytes: e.bytes,
        tamano: e.tamano,
        ms: e.ms,
        urlFinal: e.urlFinal,
        fecha: e.fecha,
        aviso: aviso,
      );

  /// Libera suscripciones.
  void dispose() {
    _subMsg?.cancel();
    _subEstado?.cancel();
    _fallarPendientes('Cerrado.');
  }
}
