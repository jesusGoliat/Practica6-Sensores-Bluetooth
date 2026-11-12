/// Servidor A: atiende PETICION y hace la consulta HTTPS.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/foundation.dart';

import '../dominio/codigos_web.dart';
import '../dominio/limitador_peticiones.dart';
import '../dominio/validador_destino.dart';
import 'cliente_http.dart';

/// Límites del contrato.
abstract final class LimitesWeb {
  static const int maxCuerpo = 256 * 1024;
  static const int maxImagen = 64 * 1024;
  static const int maxRedirecciones = 3;

  /// Tope práctico del sobre JSON (el enlace admite 64 KiB reensamblados).
  static const int maxRespuestaEnlace = 64000;
  static const Set<String> tiposTexto = {'text/plain', 'application/json', 'text/html'};
  static const Set<String> tiposImagen = {'image/jpeg', 'image/png'};
}

/// Mensaje de respuesta listo para enviar.
class MensajeWeb {
  /// Crea un mensaje [tipo] (`RESPUESTA` o `ERROR_WEB`).
  const MensajeWeb(this.tipo, this.datos);

  /// Tipo del sobre.
  final String tipo;

  /// Datos del sobre.
  final Map<String, dynamic> datos;

  /// `true` si es `ERROR_WEB`.
  bool get esError => tipo == TiposMensaje.errorWeb;
}

/// Línea del registro de peticiones atendidas.
class RegistroPeticion {
  /// Crea un registro.
  const RegistroPeticion({
    required this.req,
    required this.url,
    required this.fecha,
    required this.resultado,
    this.estado,
    this.ms = 0,
    this.duplicada = false,
  });

  final String req;
  final String url;
  final DateTime fecha;

  /// `ok` o el código de error.
  final String resultado;
  final int? estado;
  final int ms;
  final bool duplicada;
}

class _Fallo implements Exception {
  _Fallo(this.codigo, this.mensaje, [this.motivo]);
  final String codigo;
  final String mensaje;
  final MotivoRechazo? motivo;
}

class _Cancelacion {
  bool cancelada = false;
}

/// Lógica del servidor A.
class ServidorConsulta extends ChangeNotifier {
  /// [tiempoLimite] (10 s) cubre todo, incluido [retrasoDiag] (12 s).
  ServidorConsulta({
    ValidadorDestino? validador,
    ClienteHttp? http,
    LimitadorPeticiones? limitador,
    this.tiempoLimite = const Duration(seconds: 10),
    this.retrasoDiag = const Duration(seconds: 12),
    DateTime Function()? reloj,
    this.maxRegistro = 100,
  })  : validador = validador ?? ValidadorDestino(),
        http = http ?? ClienteHttpIo(),
        _limitador = limitador ?? LimitadorPeticiones(reloj: reloj),
        _reloj = reloj ?? DateTime.now;

  final ValidadorDestino validador;
  final ClienteHttp http;
  final Duration tiempoLimite;
  final Duration retrasoDiag;
  final int maxRegistro;
  final LimitadorPeticiones _limitador;
  final DateTime Function() _reloj;

  /// Modo diagnóstico: añade [retrasoDiag] antes de pedir (provoca `timeout`).
  bool retrasoDiagnostico = false;

  /// Cambia el modo diagnóstico y notifica.
  void ponerRetraso(bool v) {
    retrasoDiagnostico = v;
    notifyListeners();
  }

  final LinkedHashMap<String, Future<MensajeWeb>> _respondidas = LinkedHashMap();
  final List<RegistroPeticion> _registro = [];
  StreamSubscription<Sobre>? _sub;

  /// Registro, más reciente primero.
  List<RegistroPeticion> get registro => List.unmodifiable(_registro);

  /// Peticiones hechas realmente a Internet (para pruebas/diagnóstico).
  int salidasAInternet = 0;

  /// Atiende peticiones de [enlace] (sesión nueva: reinicia límite y duplicados).
  void vincular(Enlace enlace) {
    soltar();
    _limitador.reiniciar();
    _respondidas.clear();
    _sub = enlace.mensajes.listen((s) {
      if (s.canal == Canales.web && s.tipo == TiposMensaje.peticion) {
        unawaited(_alPeticion(enlace, s));
      }
    });
  }

  /// Deja de escuchar.
  void soltar() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _alPeticion(Enlace enlace, Sobre s) async {
    final req = s.datos['req'];
    final url = s.datos['url'];
    MensajeWeb m;
    if (req is! String || req.isEmpty || url is! String) {
      m = MensajeWeb(TiposMensaje.errorWeb, {
        'req': req is String ? req : '',
        'codigo': CodigosWeb.formato,
        'mensaje': CodigosWeb.describir(CodigosWeb.formato),
      });
    } else {
      m = await atender(req, url);
    }
    try {
      await enlace.enviar(Canales.web, s.sesion, m.tipo, m.datos);
    } catch (_) {
      // El cliente se fue: la respuesta queda guardada por si reenvía la req.
    }
  }

  /// Procesa una petición. Una `req` repetida devuelve la respuesta guardada.
  Future<MensajeWeb> atender(String req, String url) {
    final previa = _respondidas[req];
    if (previa != null) {
      unawaited(previa.then((m) => _anotar(req, url, m, 0, duplicada: true)));
      return previa;
    }
    final sw = Stopwatch()..start();
    final f = _procesar(req, url);
    _respondidas[req] = f;
    while (_respondidas.length > 200) {
      _respondidas.remove(_respondidas.keys.first);
    }
    return f.then((m) {
      _anotar(req, url, m, sw.elapsedMilliseconds);
      return m;
    });
  }

  void _anotar(String req, String url, MensajeWeb m, int ms, {bool duplicada = false}) {
    _registro.insert(
      0,
      RegistroPeticion(
        req: req,
        url: url,
        fecha: _reloj(),
        resultado: m.esError ? m.datos['codigo'] as String : 'ok',
        estado: m.datos['estado'] as int?,
        ms: (m.datos['ms'] as int?) ?? ms,
        duplicada: duplicada,
      ),
    );
    if (_registro.length > maxRegistro) _registro.removeLast();
    notifyListeners();
  }

  Future<MensajeWeb> _procesar(String req, String url) async {
    final token = _Cancelacion();
    final sw = Stopwatch()..start();
    try {
      return await _ejecutar(req, url, token, sw).timeout(tiempoLimite);
    } on TimeoutException {
      token.cancelada = true;
      return _error(req, CodigosWeb.timeout);
    } on _Fallo catch (f) {
      return _error(req, f.codigo, f.mensaje, f.motivo);
    } on SocketException {
      return _error(req, CodigosWeb.sinInternet);
    } on HandshakeException {
      return _error(req, CodigosWeb.red, 'Falló TLS en el dispositivo A.');
    } catch (e) {
      return _error(req, CodigosWeb.red, 'Falló la red en A: $e');
    }
  }

  MensajeWeb _error(String req, String codigo, [String? mensaje, MotivoRechazo? motivo]) =>
      MensajeWeb(TiposMensaje.errorWeb, {
        'req': req,
        'codigo': codigo,
        'mensaje': mensaje ?? CodigosWeb.describir(codigo),
        if (motivo != null) 'motivo': motivo.name,
      });

  Future<MensajeWeb> _ejecutar(String req, String url, _Cancelacion t, Stopwatch sw) async {
    final v = await validador.validar(url);
    if (!v.ok) {
      throw _Fallo(CodigosWeb.destinoRechazado, v.motivo!.mensaje, v.motivo);
    }
    if (!_limitador.intentar()) throw _Fallo(CodigosWeb.limite, CodigosWeb.describir(CodigosWeb.limite));
    if (retrasoDiagnostico) {
      await Future<void>.delayed(retrasoDiag);
      if (t.cancelada) throw _Fallo(CodigosWeb.timeout, '');
    }
    var actual = v.uri!;
    var saltos = 0;
    while (true) {
      if (t.cancelada) throw _Fallo(CodigosWeb.timeout, '');
      salidasAInternet++;
      final r = await http.obtener(actual, maxBytes: LimitesWeb.maxCuerpo);
      if (t.cancelada) throw _Fallo(CodigosWeb.timeout, '');
      if (const {301, 302, 303, 307, 308}.contains(r.estado) && r.ubicacion != null) {
        if (saltos >= LimitesWeb.maxRedirecciones) {
          throw _Fallo(CodigosWeb.destinoRechazado,
              MotivoRechazo.demasiadasRedirecciones.mensaje, MotivoRechazo.demasiadasRedirecciones);
        }
        saltos++;
        final Uri siguiente;
        try {
          siguiente = actual.resolve(r.ubicacion!);
        } on FormatException {
          throw _Fallo(CodigosWeb.destinoRechazado, MotivoRechazo.urlInvalida.mensaje,
              MotivoRechazo.urlInvalida);
        }
        final vs = await validador.validar(siguiente.toString());
        if (!vs.ok) {
          throw _Fallo(CodigosWeb.destinoRechazado, 'Redirección rechazada: ${vs.motivo!.mensaje}',
              vs.motivo);
        }
        actual = vs.uri!;
        continue;
      }
      return _armar(req, r, actual, sw.elapsedMilliseconds);
    }
  }

  MensajeWeb _armar(String req, RespuestaHttp r, Uri finalUri, int ms) {
    if (r.excedido) {
      throw _Fallo(CodigosWeb.demasiadoGrande, 'La respuesta excede 256 KiB.');
    }
    final tipo = (r.tipoContenido ?? '').split(';').first.trim().toLowerCase();
    final datos = <String, dynamic>{
      'req': req,
      'estado': r.estado,
      'tipo': tipo,
      'bytes': r.cuerpo.length,
      'ms': ms,
      'urlFinal': finalUri.toString(),
      'fecha': _reloj().toUtc().toIso8601String(),
    };
    if (LimitesWeb.tiposTexto.contains(tipo)) {
      datos['cuerpo'] = utf8.decode(r.cuerpo, allowMalformed: true);
    } else if (LimitesWeb.tiposImagen.contains(tipo) && r.cuerpo.length <= LimitesWeb.maxImagen) {
      datos['b64'] = base64Encode(r.cuerpo);
    } else {
      throw _Fallo(CodigosWeb.formatoNoAdmitido,
          'Formato no admitido: ${tipo.isEmpty ? 'sin tipo' : tipo}'
          '${LimitesWeb.tiposImagen.contains(tipo) ? ' (imagen mayor de 64 KiB)' : ''}.');
    }
    if (utf8.encode(jsonEncode(datos)).length > LimitesWeb.maxRespuestaEnlace) {
      throw _Fallo(CodigosWeb.demasiadoGrande,
          'La respuesta no cabe en un mensaje Bluetooth (máx. ~64 KB).');
    }
    return MensajeWeb(TiposMensaje.respuesta, datos);
  }

  @override
  void dispose() {
    soltar();
    super.dispose();
  }
}
