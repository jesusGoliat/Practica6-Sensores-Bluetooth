import 'package:intl/intl.dart';

/// Formato legible de tamaños, fechas y duraciones.
abstract final class Formato {
  static String bytes(int? valor) {
    if (valor == null || valor < 0) return 'No disponible';
    if (valor < 1024) return '$valor B';
    const unidades = <String>['KB', 'MB', 'GB', 'TB'];
    var tamano = valor.toDouble();
    var unidad = -1;
    while (tamano >= 1024 && unidad < unidades.length - 1) {
      tamano /= 1024;
      unidad++;
    }
    return '${tamano.toStringAsFixed(tamano >= 10 ? 0 : 1)} ${unidades[unidad]}';
  }

  static String fecha(DateTime? valor) {
    if (valor == null) return 'No disponible';
    return DateFormat('d MMM y, HH:mm', 'es_MX').format(valor.toLocal());
  }

  static String duracion(int segundos) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
