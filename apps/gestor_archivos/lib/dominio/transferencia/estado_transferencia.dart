enum EstadoTransferencia {
  pendiente,
  enCurso,
  completado,
  cancelado,
  fallido;

  String get etiqueta => switch (this) {
        pendiente => 'Pendiente',
        enCurso => 'En curso',
        completado => 'Completado',
        cancelado => 'Cancelado',
        fallido => 'Fallido',
      };

  bool get esFinal => this == completado || this == cancelado || this == fallido;

  /// Transiciones legales. `completado` solo desde `enCurso`.
  bool puedePasarA(EstadoTransferencia nuevo) => switch (this) {
        pendiente => nuevo == enCurso || nuevo == cancelado || nuevo == fallido,
        enCurso => nuevo == completado || nuevo == cancelado || nuevo == fallido,
        _ => false,
      };
}

class TransicionInvalida implements Exception {
  const TransicionInvalida(this.mensaje);
  final String mensaje;
  @override
  String toString() => 'TransicionInvalida: $mensaje';
}
