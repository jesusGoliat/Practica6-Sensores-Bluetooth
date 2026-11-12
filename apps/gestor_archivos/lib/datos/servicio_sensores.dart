import 'dart:async';
import 'dart:math';

import 'package:sensores/sensores.dart';

import 'ajustes_app.dart';

/// Fábrica de controladores de sensores (físicos o simulados según Ajustes).
class ServicioSensores {
  ServicioSensores(this.ajustes);

  final AjustesApp ajustes;
  final _inyeccion = StreamController<List<double>>.broadcast();

  /// Un controlador nuevo por consumidor; quien lo crea lo libera.
  ControladorSensor crear(TipoSensor tipo) {
    final FuenteSensor fuente = ajustes.sensoresSimulados
        ? FuenteSimulada(tipo, flujo: _flujoSimulado(tipo))
        : FuenteSensoresPlus(tipo);
    return ControladorSensor(fuente);
  }

  /// Demo: provoca una lectura de ~40 m/s² en el acelerómetro simulado
  /// (cuenta como sacudida solo si los sensores simulados están activos).
  void inyectarSacudida() => _inyeccion.add(const [35.0, 25.0, 9.8]);

  Stream<List<double>> _flujoSimulado(TipoSensor tipo) {
    var t = 0;
    final base = Stream<List<double>>.periodic(const Duration(milliseconds: 100), (_) {
      t++;
      final a = t / 5;
      return tipo == TipoSensor.acelerometro
          ? <double>[0.6 * sin(a), 0.4 * cos(a), 9.8 + 0.1 * sin(a * 2)]
          : <double>[0.05 * sin(a), 0.03 * cos(a), 0.02 * sin(a * 3)];
    });
    if (tipo != TipoSensor.acelerometro) return base;
    final c = StreamController<List<double>>();
    StreamSubscription<List<double>>? s1, s2;
    c.onListen = () {
      s1 = base.listen(c.add);
      s2 = _inyeccion.stream.listen(c.add);
    };
    c.onCancel = () async {
      await s1?.cancel();
      await s2?.cancel();
    };
    return c.stream;
  }

  void dispose() => _inyeccion.close();
}
