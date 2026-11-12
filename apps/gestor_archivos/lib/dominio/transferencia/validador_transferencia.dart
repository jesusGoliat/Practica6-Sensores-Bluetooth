import 'metadatos_archivo.dart';

/// Motivo de rechazo de una oferta; [codigo] coincide con el catálogo de errores.
class ErrorTransferencia {
  const ErrorTransferencia(this.codigo, this.mensaje);
  final String codigo; // nombre | tipo | tamano | formato
  final String mensaje;
  @override
  String toString() => 'ErrorTransferencia($codigo): $mensaje';
}

/// Reglas de la transferencia (docs/diseno-p6.md).
abstract final class ValidadorTransferencia {
  static const int maxBytes = 512 * 1024;
  static const int maxNombre = 80;
  static const Set<String> tipos = {'txt', 'json', 'xml', 'jpg'};

  static final RegExp _caracteresValidos = RegExp(r'^[A-Za-z0-9._ \-áéíóúñÁÉÍÓÚÑ]+$');
  static final RegExp _sha = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Extensión en minúsculas sin punto, o cadena vacía.
  static String extension(String nombre) {
    final i = nombre.lastIndexOf('.');
    return (i < 0 || i == nombre.length - 1) ? '' : nombre.substring(i + 1).toLowerCase();
  }

  /// Tipo lógico para una extensión (`jpeg` -> `jpg`), o `null` si no se permite.
  static String? tipoDeExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpeg') return 'jpg';
    return tipos.contains(e) ? e : null;
  }

  static String? tipoDeNombre(String nombre) => tipoDeExtension(extension(nombre));

  /// ¿Se puede enviar? Devuelve el motivo si no (para deshabilitar la acción).
  static String? motivoNoEnviable(String nombre, int? tamano) {
    if (tipoDeNombre(nombre) == null) {
      return 'Solo se pueden enviar archivos txt, json, xml y jpg.';
    }
    if (tamano != null && tamano > maxBytes) {
      return 'El archivo supera el límite de 512 KiB.';
    }
    if (tamano != null && tamano == 0) return 'El archivo está vacío.';
    return null;
  }

  /// Convierte un nombre real en un nombre lógico permitido (lado emisor):
  /// reemplaza caracteres no permitidos por `_`, elimina `..` y recorta a 80
  /// conservando la extensión.
  static String sanear(String nombre) {
    var s = nombre.split(RegExp(r'[/\\]')).last;
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9._ \-áéíóúñÁÉÍÓÚÑ]'), '_');
    while (s.contains('..')) {
      s = s.replaceAll('..', '.');
    }
    s = s.trim();
    if (s.length > maxNombre) {
      final ext = extension(s);
      final sufijo = ext.isEmpty ? '' : '.$ext';
      s = s.substring(0, maxNombre - sufijo.length) + sufijo;
    }
    return s;
  }

  /// Validación estricta de un nombre recibido (no se corrige, se rechaza).
  static ErrorTransferencia? validarNombre(String nombre, String tipo) {
    if (nombre.isEmpty) return const ErrorTransferencia('nombre', 'El nombre está vacío.');
    if (nombre.length > maxNombre) {
      return const ErrorTransferencia('nombre', 'El nombre excede 80 caracteres.');
    }
    if (nombre.contains('/') || nombre.contains(r'\') || nombre.contains('..')) {
      return const ErrorTransferencia('nombre', 'El nombre contiene separadores de ruta o «..».');
    }
    if (!_caracteresValidos.hasMatch(nombre)) {
      return const ErrorTransferencia('nombre', 'El nombre contiene caracteres no permitidos.');
    }
    final ext = extension(nombre);
    if (ext.isEmpty || nombre.startsWith('.') && nombre.indexOf('.', 1) < 0) {
      return const ErrorTransferencia('tipo', 'El nombre no tiene extensión.');
    }
    final deExt = tipoDeExtension(ext);
    if (deExt == null) {
      return ErrorTransferencia('tipo', 'La extensión .$ext no está permitida.');
    }
    if (deExt != tipo) {
      return ErrorTransferencia('tipo', 'La extensión .$ext no coincide con el tipo $tipo.');
    }
    return null;
  }

  /// Valida una oferta completa. `null` si es aceptable.
  static ErrorTransferencia? validarOferta(MetadatosArchivo m) {
    if (!tipos.contains(m.tipo)) {
      return ErrorTransferencia('tipo', 'Tipo no permitido: ${m.tipo}.');
    }
    final n = validarNombre(m.nombre, m.tipo);
    if (n != null) return n;
    if (m.longitud <= 0) return const ErrorTransferencia('tamano', 'El archivo está vacío.');
    if (m.longitud > maxBytes) {
      return const ErrorTransferencia('tamano', 'El archivo supera el límite de 512 KiB.');
    }
    if (m.bloque != MetadatosArchivo.tamanoBloque) {
      return const ErrorTransferencia('formato', 'Tamaño de bloque no soportado.');
    }
    if (!_sha.hasMatch(m.sha256)) {
      return const ErrorTransferencia('formato', 'SHA-256 mal formado.');
    }
    return null;
  }

  /// Nombre de destino único: `nota.txt`, `nota (2).txt`, `nota (3).txt`…
  static String nombreUnico(String nombre, bool Function(String) existe) {
    if (!existe(nombre)) return nombre;
    final i = nombre.lastIndexOf('.');
    final base = i > 0 ? nombre.substring(0, i) : nombre;
    final ext = i > 0 ? nombre.substring(i) : '';
    var n = 2;
    while (existe('$base ($n)$ext')) {
      n++;
    }
    return '$base ($n)$ext';
  }
}
