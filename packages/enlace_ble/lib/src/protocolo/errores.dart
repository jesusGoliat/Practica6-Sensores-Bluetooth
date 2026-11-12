/// Errores del protocolo de enlace.
library;

/// Mensaje recibido que viola el formato del protocolo.
///
/// [codigo] es uno de `version`, `formato`, `campo` o `fragmento`.
class ErrorProtocolo implements Exception {
  /// Crea el error con su [codigo] y un [mensaje] legible en español.
  const ErrorProtocolo(this.codigo, this.mensaje);

  /// Código corto y estable (también viaja en el sobre `ERROR`).
  final String codigo;

  /// Descripción para mostrar o registrar.
  final String mensaje;

  @override
  String toString() => 'ErrorProtocolo($codigo): $mensaje';
}

/// Fallo al enviar por el [Enlace] (sin ACK, desconectado, cerrado...).
class ErrorEnlace implements Exception {
  /// Crea el error con un [mensaje] legible en español.
  const ErrorEnlace(this.mensaje);

  /// Descripción para mostrar o registrar.
  final String mensaje;

  @override
  String toString() => 'ErrorEnlace: $mensaje';
}
