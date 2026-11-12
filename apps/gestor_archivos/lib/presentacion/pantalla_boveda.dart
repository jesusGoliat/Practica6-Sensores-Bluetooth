import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/boveda.dart';
import '../datos/estado_gestor.dart';
import '../datos/servicio_biometria.dart';
import '../dominio/modelos.dart';
import 'pantalla_visor.dart';

const String notaBiometria =
    'La biometría solo confirma tu identidad ante el sistema; la app no recibe '
    'tu huella y los archivos no se cifran.';

/// Bóveda: `protegido/` del espacio privado. Cada apertura pide autenticación
/// y se vuelve a bloquear al pasar a segundo plano o al salir.
class PantallaBoveda extends StatefulWidget {
  const PantallaBoveda({super.key});

  @override
  State<PantallaBoveda> createState() => _EstadoPantallaBoveda();
}

class _EstadoPantallaBoveda extends State<PantallaBoveda> with WidgetsBindingObserver {
  late final EstadoBoveda _boveda = context.read<EstadoBoveda>();
  bool _autenticando = false;
  String? _mensaje;
  int _version = 0;
  Future<List<EntradaArchivo>>? _futuro;
  int _versionFuturo = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boveda.bloquear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autenticar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (_autenticando) return;
    if (estado == AppLifecycleState.paused || estado == AppLifecycleState.hidden) {
      _boveda.bloquear();
      _futuro = null;
      if (mounted) setState(() => _mensaje = 'Bóveda bloqueada al pasar a segundo plano.');
    }
  }

  Future<void> _autenticar() async {
    if (_autenticando || !mounted) return;
    final auth = context.read<Autenticador>();
    setState(() => _autenticando = true);
    final r = await auth.autenticar('Confirma tu identidad para abrir la Bóveda');
    if (!mounted) return;
    setState(() {
      _autenticando = false;
      _mensaje = r.esExito ? null : r.explicacion;
      if (r.esExito) _futuro = null;
    });
    if (r.esExito) _boveda.desbloquear();
  }

  Future<void> _eliminar(EntradaArchivo e) async {
    final ok = await confirmarAccion(context,
        titulo: '${T.eliminar} ${e.nombre}',
        mensaje: 'El archivo se eliminará de forma permanente.',
        textoConfirmar: T.eliminar,
        destructivo: true);
    if (!ok || !mounted) return;
    final r = await context.read<Autenticador>().autenticar('Confirma tu identidad para eliminar ${e.nombre}');
    if (!mounted) return;
    if (!r.esExito) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(r.explicacion)));
      return;
    }
    await _boveda.servicio.eliminar(e);
    if (mounted) setState(() => _version++);
  }

  /// Una sola consulta por desbloqueo/versión (evita relistar en cada build).
  Future<List<EntradaArchivo>> _listado(EstadoBoveda b) {
    if (_futuro == null || _versionFuturo != _version) {
      _versionFuturo = _version;
      _futuro = b.listar();
    }
    return _futuro!;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boveda.bloquear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<EstadoBoveda>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bóveda')),
      body: Column(children: [
        Expanded(child: b.desbloqueada ? _lista(b) : _bloqueada()),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(notaBiometria, key: Key('nota-biometria'), textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _bloqueada() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 12),
            const Text('La Bóveda está bloqueada', style: TextStyle(fontSize: 18)),
            if (_mensaje != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_mensaje!, key: const Key('mensaje-boveda'), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('btn-desbloquear'),
              onPressed: _autenticando ? null : _autenticar,
              icon: const Icon(Icons.fingerprint),
              label: Text(_autenticando ? 'Esperando al sistema…' : 'Desbloquear'),
            ),
          ]),
        ),
      );

  Widget _lista(EstadoBoveda b) => FutureBuilder<List<EntradaArchivo>>(
        future: _listado(b),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final datos = snap.data ?? const <EntradaArchivo>[];
          if (datos.isEmpty) {
            return const EstadoVacio(
                icono: Icons.lock_open,
                titulo: 'Bóveda vacía',
                mensaje: 'Usa «Mover a la Bóveda» en el menú de un archivo del explorador.');
          }
          return ListView(children: [
            for (final e in datos)
              ListTile(
                key: Key('boveda-${e.nombre}'),
                leading: Icon(e.esCarpeta ? Icons.folder : Icons.description_outlined),
                title: Text(e.nombre),
                subtitle: Text(e.esCarpeta ? 'Carpeta' : Formato.bytes(e.tamano)),
                trailing: IconButton(
                    tooltip: T.eliminar,
                    onPressed: () => _eliminar(e),
                    icon: const Icon(Icons.delete_outline)),
                onTap: e.esCarpeta || !MapaTipos.tipoDe(e.nombre).tieneVisor
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        final archivo = await context.read<EstadoGestor>().abrirArchivo(e);
                        nav.push(MaterialPageRoute<void>(
                            builder: (_) => PantallaVisor(archivo: archivo)));
                      },
              ),
          ]);
        },
      );
}
