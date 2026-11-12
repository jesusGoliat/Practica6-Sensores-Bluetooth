import 'package:mime/mime.dart';

/// Tipo de contenido y clasificación de un archivo por su extensión.
class InfoTipo {
  const InfoTipo({
    required this.extension,
    required this.mime,
    required this.utType,
    required this.descripcion,
    this.esTexto = false,
    this.esMarkdown = false,
    this.esJson = false,
    this.esXml = false,
    this.esImagen = false,
    this.conocido = true,
  });

  final String extension;
  final String mime;
  final String utType;
  final String descripcion;
  final bool esTexto;
  final bool esMarkdown;
  final bool esJson;
  final bool esXml;
  final bool esImagen;
  final bool conocido;

  bool get tieneVisor => esTexto || esMarkdown || esJson || esXml || esImagen;
}

/// Tabla extensión → MIME/UTType. No se inventa un tipo cuando no se conoce:
/// se devuelve `conocido = false` para que la UI muestre "No disponible".
abstract final class MapaTipos {
  static const Map<String, InfoTipo> _tabla = <String, InfoTipo>{
    'txt': InfoTipo(
      extension: 'txt',
      mime: 'text/plain',
      utType: 'public.plain-text',
      descripcion: 'Texto',
      esTexto: true,
    ),
    'md': InfoTipo(
      extension: 'md',
      mime: 'text/markdown',
      utType: 'net.daringfireball.markdown',
      descripcion: 'Markdown',
      esTexto: true,
      esMarkdown: true,
    ),
    'json': InfoTipo(
      extension: 'json',
      mime: 'application/json',
      utType: 'public.json',
      descripcion: 'JSON',
      esTexto: true,
      esJson: true,
    ),
    'xml': InfoTipo(
      extension: 'xml',
      mime: 'application/xml',
      utType: 'public.xml',
      descripcion: 'XML',
      esTexto: true,
      esXml: true,
    ),
    'csv': InfoTipo(
      extension: 'csv',
      mime: 'text/csv',
      utType: 'public.comma-separated-values-text',
      descripcion: 'CSV',
      esTexto: true,
    ),
    'log': InfoTipo(
      extension: 'log',
      mime: 'text/plain',
      utType: 'public.plain-text',
      descripcion: 'Registro',
      esTexto: true,
    ),
    'yaml': InfoTipo(
      extension: 'yaml',
      mime: 'application/yaml',
      utType: 'public.yaml',
      descripcion: 'YAML',
      esTexto: true,
    ),
    'yml': InfoTipo(
      extension: 'yml',
      mime: 'application/yaml',
      utType: 'public.yaml',
      descripcion: 'YAML',
      esTexto: true,
    ),
    'png': InfoTipo(
      extension: 'png',
      mime: 'image/png',
      utType: 'public.png',
      descripcion: 'Imagen PNG',
      esImagen: true,
    ),
    'jpg': InfoTipo(
      extension: 'jpg',
      mime: 'image/jpeg',
      utType: 'public.jpeg',
      descripcion: 'Imagen JPEG',
      esImagen: true,
    ),
    'jpeg': InfoTipo(
      extension: 'jpeg',
      mime: 'image/jpeg',
      utType: 'public.jpeg',
      descripcion: 'Imagen JPEG',
      esImagen: true,
    ),
    'gif': InfoTipo(
      extension: 'gif',
      mime: 'image/gif',
      utType: 'com.compuserve.gif',
      descripcion: 'Imagen GIF',
      esImagen: true,
    ),
    'webp': InfoTipo(
      extension: 'webp',
      mime: 'image/webp',
      utType: 'org.webmproject.webp',
      descripcion: 'Imagen WebP',
      esImagen: true,
    ),
    'pdf': InfoTipo(
      extension: 'pdf',
      mime: 'application/pdf',
      utType: 'com.adobe.pdf',
      descripcion: 'PDF',
    ),
    'zip': InfoTipo(
      extension: 'zip',
      mime: 'application/zip',
      utType: 'public.zip-archive',
      descripcion: 'Archivo ZIP',
    ),
  };

  /// Devuelve el tipo del nombre/extensión. Si el MIME es detectable pero la
  /// extensión no está en la tabla, se conserva el MIME y se marca desconocido
  /// el UTType (se muestra "No disponible").
  static InfoTipo tipoDe(String nombre) {
    final punto = nombre.lastIndexOf('.');
    final extension = punto >= 0 ? nombre.substring(punto + 1).toLowerCase() : '';
    final conocido = _tabla[extension];
    if (conocido != null) return conocido;
    final mime = lookupMimeType(nombre) ?? 'application/octet-stream';
    return InfoTipo(
      extension: extension.isEmpty ? 'sin extensión' : extension,
      mime: mime,
      utType: '',
      descripcion: 'Tipo no reconocido',
      conocido: false,
    );
  }

  static InfoTipo tipoDeMime(String mime) {
    for (final tipo in _tabla.values) {
      if (tipo.mime == mime) return tipo;
    }
    return InfoTipo(
      extension: '',
      mime: mime,
      utType: '',
      descripcion: 'Tipo no reconocido',
      conocido: false,
    );
  }
}
