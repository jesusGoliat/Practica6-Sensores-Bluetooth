enum TipoErrorPartida { vacia, incompleta, formato, version, checksum, estadoInconsistente }

class ErrorPartida implements Exception {
  const ErrorPartida(this.tipo, this.mensaje);
  final TipoErrorPartida tipo;
  final String mensaje;

  @override
  String toString() => mensaje;
}
