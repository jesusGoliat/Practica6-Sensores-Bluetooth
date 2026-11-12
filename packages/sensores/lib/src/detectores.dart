import 'modelo.dart';

/// Dirección de inclinación.
enum Direccion { ninguna, izquierda, derecha, arriba, abajo }

/// Detecta sacudidas con el acelerómetro. El tiempo sale de `instante`.
class DetectorSacudida {
  DetectorSacudida({
    this.umbral = 15.0,
    this.enfriamiento = const Duration(milliseconds: 800),
  });

  static const double gravedad = 9.80665;

  /// Aceleración (sin gravedad) necesaria, en m/s².
  final double umbral;
  final Duration enfriamiento;
  DateTime? _ultimo;

  bool procesar(LecturaSensor l) {
    if (l.tipo != TipoSensor.acelerometro || !l.esValida) return false;
    if ((l.magnitud - gravedad).abs() <= umbral) return false;
    final u = _ultimo;
    if (u != null && l.instante.difference(u) < enfriamiento) return false;
    _ultimo = l.instante;
    return true;
  }
}

/// Detecta inclinación con x/y del acelerómetro.
///
/// x > umbral = izquierda, x < -umbral = derecha,
/// y > umbral = arriba, y < -umbral = abajo (dominante gana).
class DetectorInclinacion {
  DetectorInclinacion({
    this.umbral = 3.5,
    this.repeticion = const Duration(milliseconds: 350),
  });

  final double umbral;
  final Duration repeticion;
  DateTime? _ultimo;

  Direccion procesar(LecturaSensor l) {
    if (l.tipo != TipoSensor.acelerometro || !l.esValida) return Direccion.ninguna;
    final ax = l.x.abs(), ay = l.y.abs();
    if (ax <= umbral && ay <= umbral) return Direccion.ninguna;
    final u = _ultimo;
    if (u != null && l.instante.difference(u) < repeticion) return Direccion.ninguna;
    _ultimo = l.instante;
    if (ax >= ay) return l.x > 0 ? Direccion.izquierda : Direccion.derecha;
    return l.y > 0 ? Direccion.arriba : Direccion.abajo;
  }
}

/// Detecta un giro rápido de muñeca con el giroscopio.
class DetectorGiro {
  DetectorGiro({
    this.umbral = 4.0,
    this.enfriamiento = const Duration(milliseconds: 800),
  });

  final double umbral;
  final Duration enfriamiento;
  DateTime? _ultimo;

  bool procesar(LecturaSensor l) {
    if (l.tipo != TipoSensor.giroscopio || !l.esValida) return false;
    if (l.z.abs() <= umbral && l.y.abs() <= umbral) return false;
    final u = _ultimo;
    if (u != null && l.instante.difference(u) < enfriamiento) return false;
    _ultimo = l.instante;
    return true;
  }
}
