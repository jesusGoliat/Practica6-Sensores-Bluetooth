/// Metadatos de una OFERTA de archivo (canal `archivos`).
class MetadatosArchivo {
  const MetadatosArchivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.longitud,
    required this.sha256,
    this.bloque = tamanoBloque,
  });

  /// Bloque de datos del contrato: 2 KiB.
  static const int tamanoBloque = 2048;

  final String id;
  final String nombre;
  final String tipo;
  final int longitud;
  final String sha256;
  final int bloque;

  int get totalBloques => longitud == 0 ? 0 : (longitud + bloque - 1) ~/ bloque;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'longitud': longitud,
        'sha256': sha256,
        'bloque': bloque,
      };

  /// Devuelve `null` si faltan campos o tienen tipo incorrecto.
  static MetadatosArchivo? desdeJson(Map<String, dynamic> j) {
    final id = j['id'], nombre = j['nombre'], tipo = j['tipo'];
    final longitud = j['longitud'], sha = j['sha256'], bloque = j['bloque'];
    if (id is! String || nombre is! String || tipo is! String) return null;
    if (longitud is! int || sha is! String || bloque is! int) return null;
    return MetadatosArchivo(
        id: id, nombre: nombre, tipo: tipo, longitud: longitud, sha256: sha, bloque: bloque);
  }
}
