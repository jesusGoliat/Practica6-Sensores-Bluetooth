/// Validación de destinos HTTPS (anti-SSRF).
library;

import 'dart:io';

import 'lista_blanca.dart';

/// Motivo por el que se rechaza un destino.
enum MotivoRechazo {
  urlInvalida('La URL no es válida.'),
  esquema('Solo se permite https.'),
  credenciales('La URL no puede incluir usuario ni contraseña.'),
  ipLiteral('No se admiten direcciones IP.'),
  dominio('Dominio no permitido.'),
  puerto('Solo se permite el puerto 443.'),
  destinoPrivado('El nombre resuelve a una dirección privada, local o de loopback.'),
  demasiadasRedirecciones('Demasiadas redirecciones (máximo 3).');

  const MotivoRechazo(this.mensaje);

  /// Texto en español.
  final String mensaje;
}

/// Resultado de validar una URL.
class Validacion {
  const Validacion._(this.uri, this.motivo);

  /// Destino aceptado.
  const Validacion.valida(Uri uri) : this._(uri, null);

  /// Destino rechazado.
  const Validacion.rechazada(MotivoRechazo motivo) : this._(null, motivo);

  /// URI aceptada (si [ok]).
  final Uri? uri;

  /// Motivo del rechazo (si no [ok]).
  final MotivoRechazo? motivo;

  /// `true` si se aceptó.
  bool get ok => motivo == null;
}

/// Resuelve un nombre de host a direcciones.
typedef ResolverDns = Future<List<InternetAddress>> Function(String host);

/// Valida URLs contra la [ListaBlanca] y la resolución DNS.
class ValidadorDestino {
  /// Crea el validador. [resolver] es inyectable (por defecto DNS del sistema).
  ValidadorDestino({this.lista = ListaBlanca.contrato, ResolverDns? resolver})
      : resolver = resolver ?? InternetAddress.lookup;

  /// Lista blanca.
  final ListaBlanca lista;

  /// Paso de DNS.
  final ResolverDns resolver;

  /// Comprobaciones sin red: esquema, credenciales, IP literal, dominio, puerto.
  Validacion validarSintaxis(String url) {
    final Uri uri;
    try {
      uri = Uri.parse(url.trim());
    } on FormatException {
      return const Validacion.rechazada(MotivoRechazo.urlInvalida);
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return const Validacion.rechazada(MotivoRechazo.esquema);
    }
    if (uri.host.isEmpty) return const Validacion.rechazada(MotivoRechazo.urlInvalida);
    if (uri.userInfo.isNotEmpty) {
      return const Validacion.rechazada(MotivoRechazo.credenciales);
    }
    if (InternetAddress.tryParse(uri.host) != null) {
      return const Validacion.rechazada(MotivoRechazo.ipLiteral);
    }
    if (!lista.permite(uri.host)) return const Validacion.rechazada(MotivoRechazo.dominio);
    if (uri.hasPort && uri.port != 443) {
      return const Validacion.rechazada(MotivoRechazo.puerto);
    }
    return Validacion.valida(uri);
  }

  /// Validación completa, con resolución DNS. Las excepciones del resolvedor
  /// (p. ej. `SocketException` sin Internet) se propagan.
  Future<Validacion> validar(String url) async {
    final v = validarSintaxis(url);
    if (!v.ok) return v;
    final direcciones = await resolver(v.uri!.host);
    if (direcciones.isEmpty) {
      throw SocketException('No se pudo resolver ${v.uri!.host}');
    }
    if (direcciones.any(esDireccionNoPublica)) {
      return const Validacion.rechazada(MotivoRechazo.destinoPrivado);
    }
    return v;
  }

  /// `true` para loopback, privadas, link-local, CGNAT, no especificadas y ULA.
  static bool esDireccionNoPublica(InternetAddress d) {
    final b = d.rawAddress;
    if (b.length == 4) return _v4NoPublica(b[0], b[1]);
    if (b.length != 16) return true;
    final cero10 = b.sublist(0, 10).every((x) => x == 0);
    if (cero10 && b[10] == 0xff && b[11] == 0xff) {
      return _v4NoPublica(b[12], b[13]); // ::ffff:a.b.c.d
    }
    if (b.every((x) => x == 0)) return true; // ::
    if (b.sublist(0, 15).every((x) => x == 0) && b[15] == 1) return true; // ::1
    if ((b[0] & 0xfe) == 0xfc) return true; // fc00::/7
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true; // fe80::/10
    return false;
  }

  static bool _v4NoPublica(int a, int b) =>
      a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 100 && b >= 64 && b <= 127);
}
