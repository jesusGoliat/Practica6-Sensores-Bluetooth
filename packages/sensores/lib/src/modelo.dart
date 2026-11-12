import 'dart:math' as math;

/// Tipo de sensor de movimiento.
enum TipoSensor {
  acelerometro('Acelerómetro', 'm/s²'),
  giroscopio('Giroscopio', 'rad/s');

  const TipoSensor(this.nombre, this.unidad);

  /// Nombre para mostrar en la interfaz.
  final String nombre;

  /// Unidad de medida de las lecturas.
  final String unidad;
}

/// Procedencia de una lectura.
enum OrigenLectura { fisica, simulada }

/// Estado de un [ControladorSensor].
enum EstadoSensor { inactivo, escuchando, pausado, ausente, sinDatos, error }

/// Una lectura de tres ejes.
class LecturaSensor {
  const LecturaSensor({
    required this.tipo,
    required this.x,
    required this.y,
    required this.z,
    required this.instante,
    required this.origen,
  });

  final TipoSensor tipo;
  final double x;
  final double y;
  final double z;
  final DateTime instante;
  final OrigenLectura origen;

  /// Unidad según el tipo: 'm/s²' o 'rad/s'.
  String get unidad => tipo.unidad;

  /// Módulo del vector (x, y, z).
  double get magnitud => math.sqrt(x * x + y * y + z * z);

  /// Verdadero si los tres ejes son números finitos.
  bool get esValida => x.isFinite && y.isFinite && z.isFinite;

  @override
  String toString() => 'LecturaSensor($tipo, $x, $y, $z, $origen)';
}

/// Entrada de la bitácora de un controlador.
class EventoBitacora {
  const EventoBitacora(this.instante, this.descripcion);

  final DateTime instante;
  final String descripcion;
}
