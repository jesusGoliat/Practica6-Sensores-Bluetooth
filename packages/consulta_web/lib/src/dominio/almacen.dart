/// Almacenes de texto inyectables (persistencia de caché y favoritos).
library;

import 'dart:io';

/// Guarda y lee textos por clave.
abstract interface class AlmacenTexto {
  /// Devuelve el texto guardado o `null`.
  Future<String?> leer(String clave);

  /// Guarda [valor] bajo [clave].
  Future<void> escribir(String clave, String valor);
}

/// Almacén en memoria (pruebas).
class AlmacenMemoria implements AlmacenTexto {
  /// Contenido actual.
  final Map<String, String> datos = {};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async => datos[clave] = valor;
}

/// Almacén en archivos `consulta_web_<clave>.json` dentro de [carpeta].
class AlmacenArchivos implements AlmacenTexto {
  /// [carpeta] se evalúa en cada acceso (p. ej. `getApplicationSupportDirectory`).
  AlmacenArchivos(this.carpeta);

  /// Origen de la carpeta de datos.
  final Future<Directory> Function() carpeta;

  Future<File> _archivo(String clave) async {
    final d = await carpeta();
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}${Platform.pathSeparator}consulta_web_$clave.json');
  }

  @override
  Future<String?> leer(String clave) async {
    try {
      final f = await _archivo(clave);
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> escribir(String clave, String valor) async {
    try {
      final f = await _archivo(clave);
      await f.writeAsString(valor, flush: true);
    } catch (_) {
      // Sin persistencia: la app sigue funcionando con la copia en memoria.
    }
  }
}
