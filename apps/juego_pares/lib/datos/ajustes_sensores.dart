import 'package:flutter/foundation.dart';
import 'package:sensores/sensores.dart';

/// Fuente simulada para demostraciones: genera inclinaciones y giros en ciclo.
/// Cada suscripción crea un flujo nuevo, así que admite pausa y reanudación.
class FuenteDemo extends FuenteSimulada {
  FuenteDemo(super.tipo, {super.ausente});

  @override
  Stream<LecturaSensor> lecturas(Duration periodo) {
    return Stream<int>.periodic(periodo, (n) => n).map((n) {
      List<double> v;
      if (tipo == TipoSensor.acelerometro) {
        final ciclo = n ~/ 40;
        final fase = n % 40;
        const dirs = <List<double>>[
          [-6, 0, 9.8], // derecha
          [0, -6, 9.8], // abajo
          [6, 0, 9.8], // izquierda
          [0, 6, 9.8], // arriba
        ];
        v = fase >= 20 && fase < 25 ? dirs[ciclo % 4] : const [0, 0, 9.8];
      } else {
        final fase = n % 60;
        v = fase >= 30 && fase < 32 ? const [0, 0, 6] : const [0, 0, 0];
      }
      return LecturaSensor(
          tipo: tipo,
          x: v[0],
          y: v[1],
          z: v[2],
          instante: DateTime.now(),
          origen: OrigenLectura.simulada);
    });
  }
}

/// Ajustes de sensores compartidos: fuente física o simulada.
class AjustesSensores extends ChangeNotifier {
  bool simulados = false;
  bool ausenteSimulado = false;

  void usarSimulados(bool v) {
    simulados = v;
    notifyListeners();
  }

  void simularAusente(bool v) {
    ausenteSimulado = v;
    notifyListeners();
  }

  FuenteSensor crearFuente(TipoSensor tipo) =>
      simulados ? FuenteDemo(tipo, ausente: ausenteSimulado) : FuenteSensoresPlus(tipo);

  ControladorSensor crearControlador(TipoSensor tipo) =>
      ControladorSensor(crearFuente(tipo));
}
