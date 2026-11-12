import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/ajustes_sensores.dart';
import '../../datos/control_movimiento.dart';
import '../observador_rutas.dart';

/// Crea un [ControlMovimiento] y lo mantiene sincronizado con el ciclo de
/// vida de la app, con la visibilidad de la ruta y con [visible].
class AlcanceMovimiento extends StatefulWidget {
  const AlcanceMovimiento({
    super.key,
    required this.filas,
    required this.columnas,
    required this.alVoltear,
    required this.builder,
    this.visible = true,
  });

  final int filas;
  final int columnas;
  final bool visible;
  final void Function(int indice) alVoltear;
  final Widget Function(BuildContext context, ControlMovimiento control) builder;

  @override
  State<AlcanceMovimiento> createState() => _EstadoAlcance();
}

class _EstadoAlcance extends State<AlcanceMovimiento> with WidgetsBindingObserver, RouteAware {
  late final ControlMovimiento _control;
  bool _rutaVisible = true;
  ModalRoute<dynamic>? _ruta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _control = ControlMovimiento(
      ajustes: context.read<AjustesSensores>(),
      alVoltear: (i) => widget.alVoltear(i),
      filas: widget.filas,
      columnas: widget.columnas,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute && ruta != _ruta) {
      observadorRutas.unsubscribe(this);
      _ruta = ruta;
      observadorRutas.subscribe(this, ruta);
    }
  }

  @override
  void didUpdateWidget(AlcanceMovimiento anterior) {
    super.didUpdateWidget(anterior);
    _control.configurarTablero(widget.filas, widget.columnas);
    _control.visible = widget.visible && _rutaVisible;
  }

  @override
  void didPushNext() {
    _rutaVisible = false;
    _control.visible = false;
  }

  @override
  void didPopNext() {
    _rutaVisible = true;
    _control.visible = widget.visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _control.primerPlano = estado == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    observadorRutas.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _control,
        builder: (context, _) => widget.builder(context, _control),
      );
}

/// Interruptor «Control por movimiento» con su estado.
class SwitchMovimiento extends StatelessWidget {
  const SwitchMovimiento({super.key, required this.control});

  final ControlMovimiento control;

  @override
  Widget build(BuildContext context) {
    final texto = !control.encendido
        ? 'Inclina para mover el cursor y gira la muñeca para voltear.'
        : control.ausente
            ? 'Sensor ausente en este dispositivo: juega con toques.'
            : control.escuchando
                ? 'Activo${control.simulado ? ' (valores simulados)' : ''}: inclina para mover, gira para voltear.'
                : 'En pausa (pantalla oculta o app en segundo plano).';
    return SwitchListTile(
      key: const Key('switch-movimiento'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: const Icon(Icons.screen_rotation_alt_outlined),
      title: const Text('Control por movimiento'),
      subtitle: Text(texto),
      value: control.encendido,
      onChanged: (v) => control.alternar(v),
    );
  }
}
