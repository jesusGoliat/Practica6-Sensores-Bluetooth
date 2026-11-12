/// Abstracción del cliente HTTP del servidor A (inyectable en pruebas).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Respuesta HTTP cruda (sin seguir redirecciones).
class RespuestaHttp {
  /// Crea una respuesta.
  const RespuestaHttp({
    required this.estado,
    this.tipoContenido,
    this.ubicacion,
    required this.cuerpo,
    this.excedido = false,
  });

  /// Código HTTP.
  final int estado;

  /// Cabecera `content-type` completa.
  final String? tipoContenido;

  /// Cabecera `location` (redirecciones).
  final String? ubicacion;

  /// Cuerpo leído (a lo sumo `maxBytes + 1` bytes).
  final Uint8List cuerpo;

  /// El cuerpo superó el máximo.
  final bool excedido;
}

/// GET de una sola petición, sin seguir redirecciones.
abstract interface class ClienteHttp {
  /// Pide [uri]; lee como máximo [maxBytes] + 1 bytes.
  Future<RespuestaHttp> obtener(Uri uri, {required int maxBytes});
}

/// Implementación con `dart:io`.
class ClienteHttpIo implements ClienteHttp {
  @override
  Future<RespuestaHttp> obtener(Uri uri, {required int maxBytes}) async {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'P6-consulta-web/1.0';
    try {
      final req = await c.getUrl(uri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/*, image/jpeg, image/png');
      final resp = await req.close();
      final b = BytesBuilder(copy: false);
      var excedido = resp.contentLength > maxBytes;
      if (!excedido) {
        await for (final trozo in resp) {
          b.add(trozo);
          if (b.length > maxBytes) {
            excedido = true;
            break;
          }
        }
      }
      return RespuestaHttp(
        estado: resp.statusCode,
        tipoContenido: resp.headers.value(HttpHeaders.contentTypeHeader),
        ubicacion: resp.headers.value(HttpHeaders.locationHeader),
        cuerpo: b.takeBytes(),
        excedido: excedido,
      );
    } finally {
      c.close(force: true);
    }
  }
}
