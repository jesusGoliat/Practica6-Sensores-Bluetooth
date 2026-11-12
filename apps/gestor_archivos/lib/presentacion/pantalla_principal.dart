import 'package:comun/comun.dart';
import 'package:consulta_web/consulta_web.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensores/sensores.dart';

import '../datos/ajustes_app.dart';
import '../datos/estado_gestor.dart';
import '../datos/servicio_sensores.dart';
import '../datos/transferencia/estado_transferencias.dart';
import '../dominio/modelos.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_boveda.dart';
import 'pantalla_compartir.dart';
import 'pantalla_explorador.dart';
import 'pantalla_favoritos.dart';
import 'pantalla_recientes.dart';
import 'widgets/dialogo_tema.dart';
import 'widgets/dialogos_transferencia.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> with WidgetsBindingObserver {
  int _indice = 0;
  late final EstadoGestor _gestor;
  bool _mostrandoAviso = false;

  late final EstadoTransferencias _transferencias;
  late final AjustesApp _ajustes;
  late final ServicioSensores _sensores;
  bool _dialogoOferta = false;

  // Sacudir para actualizar: solo con el explorador visible y la app en primer plano.
  ControladorSensor? _acel;
  final DetectorSacudida _detector = DetectorSacudida();
  LecturaSensor? _ultimaLectura;
  bool _simuladosUsados = false;
  bool _appActiva = true;
  bool _rutaVisible = true;
  bool _sensoresAbiertos = false;
  Animation<double>? _secundaria;

  @override
  void initState() {
    super.initState();
    _gestor = context.read<EstadoGestor>();
    _transferencias = context.read<EstadoTransferencias>();
    _ajustes = context.read<AjustesApp>();
    _sensores = context.read<ServicioSensores>();
    _gestor.addListener(_alCambiarEstado);
    _transferencias.addListener(_alCambiarTransferencias);
    _ajustes.addListener(_actualizarSacudida);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarSacudida());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nueva = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(nueva, _secundaria)) {
      _secundaria?.removeStatusListener(_alCambiarRuta);
      _secundaria = nueva;
      _secundaria?.addStatusListener(_alCambiarRuta);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secundaria?.removeStatusListener(_alCambiarRuta);
    _gestor.removeListener(_alCambiarEstado);
    _transferencias.removeListener(_alCambiarTransferencias);
    _ajustes.removeListener(_actualizarSacudida);
    _detenerSacudida();
    super.dispose();
  }

  void _alCambiarRuta(AnimationStatus _) {
    _rutaVisible = _secundaria == null || _secundaria!.status == AnimationStatus.dismissed;
    _actualizarSacudida();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _appActiva = estado == AppLifecycleState.resumed;
    _actualizarSacudida();
  }

  void _irA(int i) {
    setState(() => _indice = i);
    _actualizarSacudida();
  }

  void _detenerSacudida() {
    final c = _acel;
    if (c == null) return;
    c.removeListener(_alLeerAcelerometro);
    c.detener();
    c.dispose();
    _acel = null;
  }

  void _actualizarSacudida() {
    if (!mounted) return;
    final quiere = _ajustes.sacudirActualiza && _indice == 0 && _appActiva &&
        _rutaVisible && !_sensoresAbiertos;
    if (_acel != null && (!quiere || _simuladosUsados != _ajustes.sensoresSimulados)) {
      _detenerSacudida();
    }
    if (quiere && _acel == null) {
      _simuladosUsados = _ajustes.sensoresSimulados;
      final c = _sensores.crear(TipoSensor.acelerometro);
      _acel = c;
      c.addListener(_alLeerAcelerometro);
      c.iniciar();
    }
  }

  void _alLeerAcelerometro() {
    final l = _acel?.ultima;
    if (l == null || identical(l, _ultimaLectura)) return;
    _ultimaLectura = l;
    if (_detector.procesar(l)) {
      _gestor.recargar();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Listado actualizado (sacudida)')));
    }
  }

  Future<void> _abrirSensores() async {
    _sensoresAbiertos = true;
    _actualizarSacudida();
    final a = _sensores.crear(TipoSensor.acelerometro);
    final g = _sensores.crear(TipoSensor.giroscopio);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PantallaSensores(acelerometro: a, giroscopio: g),
      ));
    } finally {
      a.dispose();
      g.dispose();
      _sensoresAbiertos = false;
      _actualizarSacudida();
    }
  }

  /// Ejercicio 3: A (Internet) atiende a B (solo Bluetooth).
  Future<void> _abrirConsultaWeb() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const PantallaConsultaWeb()));
  }

  Future<void> _abrirBoveda() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PantallaBoveda()));
  }

  void _alCambiarTransferencias() {
    if (!mounted) return;
    final t = _transferencias;
    final oferta = t.ofertaEntrante;
    if (oferta != null && !_dialogoOferta) {
      _dialogoOferta = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _dialogoOferta = false;
          return;
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => ListenableBuilder(
            listenable: t,
            builder: (c2, _) {
              if (t.ofertaEntrante == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (c2.mounted) Navigator.of(c2).pop();
                });
                return const SizedBox.shrink();
              }
              return dialogoOferta(t, t.ofertaEntrante!);
            },
          ),
        );
        _dialogoOferta = false;
      });
    }
    final aviso = t.consumirAviso();
    if (aviso != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(aviso)));
      });
    }
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
        if (mounted) _irA(0);
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
      _irA(0);
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
      // Compartir se construye solo al visitarlo (no toca Bluetooth antes).
      _indice == 3 ? const PantallaCompartir() : const SizedBox.shrink(),
      // >>> HOOK Consulta web: aquí va la pantalla del destino futuro (ver _destinosWeb).
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
        icon: Icon(Icons.bluetooth_outlined),
        selectedIcon: Icon(Icons.bluetooth),
        label: Text('Compartir'),
      ),
      // >>> HOOK Consulta web: destino de rail (índice entre Compartir y Ajustes).
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text(T.ajustes),
      ),
    ];

    final cuerpo = IndexedStack(index: _indice, children: pantallas);
    final barraInferior = NavigationBar(
      selectedIndex: _indice,
      onDestinationSelected: _irA,
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
          key: Key('nav-compartir'),
          icon: Icon(Icons.bluetooth_outlined),
          selectedIcon: Icon(Icons.bluetooth),
          label: 'Compartir',
        ),
        // >>> HOOK Consulta web: agregar aquí NavigationDestination(key: Key('nav-web'), ...)
        //     y su pantalla/rail correspondientes (mantener el mismo orden en los tres listados).
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
            IconButton(
              key: const Key('btn-web'),
              tooltip: 'Consulta web por Bluetooth',
              icon: const Icon(Icons.travel_explore),
              onPressed: _abrirConsultaWeb,
            ),
            PopupMenuButton<String>(
              key: const Key('btn-mas'),
              tooltip: 'Más',
              onSelected: (v) {
                switch (v) {
                  case 'boveda':
                    _abrirBoveda();
                  case 'sensores':
                    _abrirSensores();
                  case 'sacudida':
                    _sensores.inyectarSacudida();
                  case 'web':
                    _abrirConsultaWeb();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'boveda', child: Text('Bóveda')),
                const PopupMenuItem(value: 'sensores', child: Text('Sensores')),
                if (_ajustes.sensoresSimulados)
                  const PopupMenuItem(value: 'sacudida', child: Text('Simular una sacudida')),
                const PopupMenuItem(
                    value: 'web', child: Text('Consulta web por Bluetooth')),
              ],
            ),
          ],
        ),
        body: ancho >= 720
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _indice,
                    onDestinationSelected: _irA,
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
