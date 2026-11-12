import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'modelo.dart';

/// Origen de lecturas de un sensor.
abstract interface class FuenteSensor {
  TipoSensor get tipo;
  OrigenLectura get origen;

  /// Falso si el sensor está ausente. Nunca lanza.
  Future<bool> disponible();

  /// Flujo de lecturas; cancelar la suscripción detiene el sensor.
  Stream<LecturaSensor> lecturas(Duration periodo);
}

/// Fuente física basada en `sensors_plus`.
class FuenteSensoresPlus implements FuenteSensor {
  FuenteSensoresPlus(this.tipo,
      {this.esperaDisponibilidad = const Duration(milliseconds: 1500)});

  @override
  final TipoSensor tipo;

  /// Tiempo máximo (≤ 1.5 s) para recibir el primer evento.
  final Duration esperaDisponibilidad;

  @override
  OrigenLectura get origen => OrigenLectura.fisica;

  Stream<LecturaSensor> _flujo(Duration periodo) {
    return switch (tipo) {
      TipoSensor.acelerometro => accelerometerEventStream(samplingPeriod: periodo)
          .map((e) => _lectura(e.x, e.y, e.z)),
      TipoSensor.giroscopio => gyroscopeEventStream(samplingPeriod: periodo)
          .map((e) => _lectura(e.x, e.y, e.z)),
    };
  }

  LecturaSensor _lectura(double x, double y, double z) => LecturaSensor(
      tipo: tipo,
      x: x,
      y: y,
      z: z,
      instante: DateTime.now(),
      origen: OrigenLectura.fisica);

  @override
  Future<bool> disponible() async {
    final completer = Completer<bool>();
    StreamSubscription<LecturaSensor>? sub;
    try {
      sub = _flujo(const Duration(milliseconds: 100)).listen(
        (_) {
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (Object _) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
        cancelOnError: true,
      );
      return await completer.future
          .timeout(esperaDisponibilidad, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      try {
        await sub?.cancel();
      } catch (_) {}
    }
  }

  @override
  Stream<LecturaSensor> lecturas(Duration periodo) => _flujo(periodo);
}

/// Fuente simulada para pruebas y demostración.
class FuenteSimulada implements FuenteSensor {
  /// [flujo] emite listas [x, y, z]; [valores] se emite cada `periodo`;
  /// [ausente] simula un dispositivo sin el sensor.
  FuenteSimulada(
    this.tipo, {
    this.flujo,
    this.valores,
    this.ausente = false,
  });

  @override
  final TipoSensor tipo;
  final bool ausente;
  final Stream<List<double>>? flujo;
  final List<List<double>>? valores;

  @override
  OrigenLectura get origen => OrigenLectura.simulada;

  @override
  Future<bool> disponible() async => !ausente;

  @override
  Stream<LecturaSensor> lecturas(Duration periodo) {
    final v = valores;
    final Stream<List<double>> base = flujo ??
        (v == null
            ? const Stream<List<double>>.empty()
            : _periodico(v, periodo));
    return base.map((d) => LecturaSensor(
        tipo: tipo,
        x: d[0],
        y: d[1],
        z: d[2],
        instante: DateTime.now(),
        origen: OrigenLectura.simulada));
  }

  static Stream<List<double>> _periodico(
      List<List<double>> valores, Duration periodo) async* {
    for (final v in valores) {
      await Future<void>.delayed(periodo);
      yield v;
    }
  }
}
