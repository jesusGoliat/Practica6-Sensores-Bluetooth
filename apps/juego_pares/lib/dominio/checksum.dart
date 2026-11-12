/// Checksum FNV-1a de 32 bits. Detecta truncamientos o alteraciones simples
/// en los tres formatos sin agregar dependencias.
String fnv1a(String texto) {
  var hash = 0x811c9dc5;
  for (final unidad in texto.codeUnits) {
    hash ^= unidad;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
