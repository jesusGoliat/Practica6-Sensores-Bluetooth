import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensores/sensores.dart';

import '../datos/ajustes_sensores.dart';

/// Abre [PantallaSensores] con la fuente física o la simulada según Ajustes.
class PantallaSensoresJuego extends StatefulWidget {
  const PantallaSensoresJuego({super.key});

  @override
  State<PantallaSensoresJuego> createState() => _EstadoPantallaSensoresJuego();
}

class _EstadoPantallaSensoresJuego extends State<PantallaSensoresJuego> {
  late final ControladorSensor _acel;
  late final ControladorSensor _giro;

  @override
  void initState() {
    super.initState();
    final ajustes = context.read<AjustesSensores>();
    _acel = ajustes.crearControlador(TipoSensor.acelerometro);
    _giro = ajustes.crearControlador(TipoSensor.giroscopio);
  }

  @override
  void dispose() {
    _acel.dispose();
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PantallaSensores(acelerometro: _acel, giroscopio: _giro);
}
