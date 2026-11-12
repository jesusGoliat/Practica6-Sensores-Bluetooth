import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Carpeta elegida por el usuario en iOS, con su bookmark de seguridad.
@immutable
class CarpetaAutorizadaIos {
  const CarpetaAutorizadaIos({
    required this.ruta,
    required this.nombre,
    required this.token,
    this.accesoConcedido = true,
    this.obsoleto = false,
  });

  /// Ruta POSIX dentro del sandbox/security scope.
  final String ruta;
  final String nombre;

  /// Bookmark en Base64 que debe guardarse para volver a abrir la carpeta.
  final String token;
  final bool accesoConcedido;
  final bool obsoleto;

  factory CarpetaAutorizadaIos.desdeMapa(Map<Object?, Object?> mapa) {
    return CarpetaAutorizadaIos(
      ruta: mapa['ruta'] as String? ?? '',
      nombre: mapa['nombre'] as String? ?? '',
      token: mapa['token'] as String? ?? '',
      accesoConcedido: mapa['acceso'] as bool? ?? true,
      obsoleto: mapa['obsoleto'] as bool? ?? false,
    );
  }
}

/// Selector de carpetas de iOS basado en UIDocumentPicker + security-scoped
/// bookmarks. Solo debe usarse cuando `Platform.isIOS` sea verdadero.
class SelectorCarpetasIos {
  static const MethodChannel _canal = MethodChannel(
    'mx.ipn.escom.p6/selector_carpetas_ios',
  );

  /// Abre el selector del sistema. Devuelve null si el usuario cancela.
  Future<CarpetaAutorizadaIos?> elegirCarpeta() async {
    final mapa = await _canal.invokeMethod<Map<Object?, Object?>>('elegirCarpeta');
    return mapa == null ? null : CarpetaAutorizadaIos.desdeMapa(mapa);
  }

  /// Resuelve un bookmark guardado. Devuelve null si ya no es válido.
  Future<CarpetaAutorizadaIos?> resolver(String token) async {
    final mapa = await _canal.invokeMethod<Map<Object?, Object?>>(
      'resolver',
      <String, Object?>{'token': token},
    );
    return mapa == null ? null : CarpetaAutorizadaIos.desdeMapa(mapa);
  }

  /// Libera el último security scope abierto por el plugin.
  Future<void> liberar() async {
    await _canal.invokeMethod<void>('liberar');
  }
}
