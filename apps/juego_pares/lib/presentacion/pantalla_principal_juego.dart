import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_juego.dart';
import 'pantalla_ajustes_juego.dart';
import 'pantalla_inicio.dart';
import 'pantalla_partidas.dart';
import 'widgets/dialogo_tema_juego.dart';

class PantallaPrincipalJuego extends StatefulWidget {
  const PantallaPrincipalJuego({super.key});

  @override
  State<PantallaPrincipalJuego> createState() => _PantallaPrincipalJuegoState();
}

class _PantallaPrincipalJuegoState extends State<PantallaPrincipalJuego> with WidgetsBindingObserver {
  int _indice = 0;
  late final EstadoJuego _juego;
  bool _avisando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _juego = context.read<EstadoJuego>();
    _juego.addListener(_alCambiar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _juego.removeListener(_alCambiar);
    _juego.autoguardarAhora();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _juego.autoguardarAhora();
      if (_juego.activa && !_juego.pausado) _juego.pausar();
    }
  }

  void _alCambiar() {
    final aviso = _juego.aviso;
    if (aviso == null || _avisando || !mounted) return;
    _avisando = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aviso)));
      _juego.limpiarAviso();
      _avisando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final juego = context.watch<EstadoJuego>();
    final pantallas = <Widget>[
      PantallaInicio(alVerPartidas: () => setState(() => _indice = 1)),
      const PantallaPartidas(),
      const PantallaAjustesJuego(),
    ];
    return PopScope(
      canPop: _indice == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _indice = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.extension_outlined, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text(T.appJuego)),
              if (juego.activa)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(Formato.duracion(juego.segundos)),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('btn-tema-juego'),
              tooltip: T.tema,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const DialogoTemaJuego(),
              ),
              icon: const Icon(Icons.palette_outlined),
            ),
          ],
        ),
        body: IndexedStack(index: _indice, children: pantallas),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: (i) => setState(() => _indice = i),
          destinations: const [
            NavigationDestination(
              key: Key('nav-jugar'),
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: T.jugar,
            ),
            NavigationDestination(
              key: Key('nav-partidas'),
              icon: Icon(Icons.save_outlined),
              selectedIcon: Icon(Icons.save),
              label: T.partidas,
            ),
            NavigationDestination(
              key: Key('nav-ajustes-juego'),
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: T.ajustes,
            ),
          ],
        ),
      ),
    );
  }
}
