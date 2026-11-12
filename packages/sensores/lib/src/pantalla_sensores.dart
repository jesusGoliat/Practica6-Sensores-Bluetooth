import 'package:flutter/material.dart';

import 'controlador.dart';
import 'modelo.dart';
import 'panel_sensor.dart';

/// Pantalla con ambos sensores, interruptor de inicio y bitácora.
class PantallaSensores extends StatefulWidget {
  const PantallaSensores({
    super.key,
    required this.acelerometro,
    required this.giroscopio,
  });

  final ControladorSensor acelerometro;
  final ControladorSensor giroscopio;

  @override
  State<PantallaSensores> createState() => _EstadoPantallaSensores();
}

class _EstadoPantallaSensores extends State<PantallaSensores>
    with WidgetsBindingObserver {
  bool _activo = false;
  bool _pausadoPorCiclo = false;

  List<ControladorSensor> get _todos =>
      [widget.acelerometro, widget.giroscopio];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_activo && !_pausadoPorCiclo) {
          _pausadoPorCiclo = true;
          for (final c in _todos) {
            c.pausar();
          }
        }
      case AppLifecycleState.resumed:
        if (_pausadoPorCiclo) {
          _pausadoPorCiclo = false;
          for (final c in _todos) {
            c.reanudar();
          }
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  void _alternar(bool valor) {
    setState(() => _activo = valor);
    _pausadoPorCiclo = false;
    for (final c in _todos) {
      if (valor) {
        c.iniciar();
      } else {
        c.detener();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _todos) {
      c.detener();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensores')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MergeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SwitchListTile(
                title: const Text('Leer sensores'),
                value: _activo,
                onChanged: _alternar,
              ),
            ),
          ),
          const Text('Las suscripciones se detienen al salir de esta '
              'pantalla y al pasar la aplicación a segundo plano.'),
          const SizedBox(height: 8),
          PanelSensor.deControlador(widget.acelerometro),
          PanelSensor.deControlador(widget.giroscopio),
          const SizedBox(height: 8),
          Text('Bitácora', style: texto.titleMedium),
          ListenableBuilder(
            listenable: Listenable.merge(_todos),
            builder: (_, _) {
              final eventos = <MapEntry<ControladorSensor, EventoBitacora>>[
                for (final c in _todos)
                  for (final e in c.bitacora) MapEntry(c, e),
              ]..sort((a, b) => b.value.instante.compareTo(a.value.instante));
              if (eventos.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(8), child: Text('Sin eventos'));
              }
              return Column(children: [
                for (final e in eventos)
                  ListTile(
                    dense: true,
                    minVerticalPadding: 12,
                    title: Text(e.value.descripcion),
                    subtitle: Text('${e.key.fuente.tipo.nombre} · '
                        '${formatoInstante(e.value.instante)}'),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
