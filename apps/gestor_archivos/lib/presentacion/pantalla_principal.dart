import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_gestor.dart';
import '../dominio/modelos.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_explorador.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_recientes.dart';
import 'widgets/dialogo_tema.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;
  late final EstadoGestor _gestor;
  bool _mostrandoAviso = false;

  @override
  void initState() {
    super.initState();
    _gestor = context.read<EstadoGestor>();
    _gestor.addListener(_alCambiarEstado);
  }

  @override
  void dispose() {
    _gestor.removeListener(_alCambiarEstado);
    super.dispose();
  }

  void _alCambiarEstado() {
    final aviso = _gestor.aviso;
    if (aviso == null || _mostrandoAviso || !mounted) return;
    _mostrandoAviso = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aviso)));
      _gestor.limpiarAviso();
      _mostrandoAviso = false;
    });
  }

  Future<void> _anadirCarpeta() async {
    try {
      final raiz = await _gestor.anadirCarpetaExterna();
      if (raiz != null) {
        await _gestor.abrirRaiz(raiz);
        if (mounted) setState(() => _indice = 0);
      }
    } catch (e) {
      if (mounted) avisarError(context, e);
    }
  }

  Future<void> _importar() async {
    try {
      final entrada = await _gestor.importarArchivo();
      if (entrada != null && mounted) {
        setState(() => _indice = 0);
      }
    } catch (e) {
      if (mounted) avisarError(context, e);
    }
  }

  Future<void> _atras() async {
    if (_indice != 0) {
      setState(() => _indice = 0);
      return;
    }
    if (_gestor.pila.isNotEmpty) {
      await _gestor.subir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gestor = context.watch<EstadoGestor>();
    final ancho = MediaQuery.sizeOf(context).width;
    final pantallas = <Widget>[
      const PantallaExplorador(),
      const PantallaFavoritos(),
      const PantallaRecientes(),
      const PantallaAjustes(),
    ];
    final destinos = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text(T.explorador),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.star_border),
        selectedIcon: Icon(Icons.star),
        label: Text(T.favoritos),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: Text(T.recientes),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text(T.ajustes),
      ),
    ];

    final cuerpo = IndexedStack(index: _indice, children: pantallas);
    final barraInferior = NavigationBar(
      selectedIndex: _indice,
      onDestinationSelected: (i) => setState(() => _indice = i),
      destinations: const <NavigationDestination>[
        NavigationDestination(
          key: Key('nav-explorador'),
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: T.explorador,
        ),
        NavigationDestination(
          key: Key('nav-favoritos'),
          icon: Icon(Icons.star_border),
          selectedIcon: Icon(Icons.star),
          label: T.favoritos,
        ),
        NavigationDestination(
          key: Key('nav-recientes'),
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: T.recientes,
        ),
        NavigationDestination(
          key: Key('nav-ajustes'),
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: T.ajustes,
        ),
      ],
    );

    return PopScope(
      canPop: _indice == 0 && gestor.pila.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                gestor.raizActual?.origen == OrigenArchivo.privado
                    ? Icons.folder_copy_outlined
                    : Icons.folder_shared_outlined,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  T.appGestor,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('btn-tema'),
              tooltip: T.tema,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const DialogoTema(),
              ),
              icon: const Icon(Icons.palette_outlined),
            ),
            IconButton(
              key: const Key('btn-anadir-carpeta'),
              tooltip: T.anadirCarpeta,
              onPressed: _anadirCarpeta,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              key: const Key('btn-importar'),
              tooltip: T.importarArchivo,
              onPressed: _importar,
              icon: const Icon(Icons.file_upload_outlined),
            ),
          ],
        ),
        body: ancho >= 720
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _indice,
                    onDestinationSelected: (i) => setState(() => _indice = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: destinos,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: cuerpo),
                ],
              )
            : cuerpo,
        bottomNavigationBar: ancho >= 720 ? null : barraInferior,
      ),
    );
  }
}
