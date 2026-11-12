import 'package:comun/comun.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../datos/estado_juego.dart';
import '../datos/repositorio_partidas.dart';
import 'pantalla_juego.dart';

class PantallaPartidas extends StatelessWidget {
  const PantallaPartidas({super.key});

  @override
  Widget build(BuildContext context) {
    final juego = context.watch<EstadoJuego>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${juego.partidas.length} partida(s) guardada(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('btn-importar-partida'),
                tooltip: 'Importar desde Archivos',
                onPressed: () async {
                  try {
                    await juego.importar();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                icon: const Icon(Icons.file_open_outlined),
              ),
              IconButton(
                key: const Key('btn-recargar-partidas'),
                tooltip: 'Recargar',
                onPressed: juego.refrescarPartidas,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: juego.partidas.isEmpty
              ? const EstadoVacio(
                  icono: Icons.save_outlined,
                  titulo: T.sinPartidas,
                  mensaje: 'Cuando guardes una partida en TXT, XML o JSON aparecerá aquí con sus metadatos y etiquetas.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: juego.partidas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TarjetaPartida(guardada: juego.partidas[i]),
                ),
        ),
      ],
    );
  }
}

class _TarjetaPartida extends StatelessWidget {
  const _TarjetaPartida({required this.guardada});

  final PartidaGuardada guardada;

  @override
  Widget build(BuildContext context) {
    final juego = context.read<EstadoJuego>();
    final estado = guardada.estado;
    final esquema = Theme.of(context).colorScheme;
    final corrupta = estado == null;
    return Card(
      key: Key('partida-${guardada.nombre}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  corrupta
                      ? Icons.warning_amber_rounded
                      : estado.victoria
                          ? Icons.emoji_events
                          : Icons.save_outlined,
                  color: corrupta
                      ? esquema.error
                      : estado.victoria
                          ? esquema.tertiary
                          : esquema.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guardada.nombreVisible,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(guardada.formato),
                ),
                PopupMenuButton<String>(
                  key: Key('menu-partida-${guardada.nombre}'),
                  onSelected: (accion) => _accion(context, juego, accion),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'cargar', child: Text(T.cargarPartida)),
                    const PopupMenuItem(value: 'contenido', child: Text(T.verContenido)),
                    const PopupMenuItem(value: 'exportar', child: Text(T.exportar)),
                    const PopupMenuItem(value: 'compartir', child: Text(T.compartir)),
                    const PopupMenuItem(value: 'etiqueta', child: Text(T.etiqueta)),
                    const PopupMenuItem(value: 'eliminar', child: Text(T.eliminar)),
                  ],
                ),
              ],
            ),
            if (corrupta)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  guardada.error ?? T.corrupta,
                  style: TextStyle(color: esquema.error),
                ),
              )
            else ...[
              const SizedBox(height: 2),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  _Meta(texto: estado.nivelEtiqueta, icono: Icons.grid_view),
                  _Meta(texto: estado.modoEtiqueta, icono: Icons.timer_outlined),
                  _Meta(texto: '${estado.puntaje} pts', icono: Icons.stars_outlined),
                  _Meta(texto: Formato.duracion(estado.tiempoSegundos), icono: Icons.schedule),
                  _Meta(texto: Formato.fecha(guardada.modificada), icono: Icons.event),
                ],
              ),
              if (estado.etiqueta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Chip(
                    avatar: const Icon(Icons.label_outline, size: 16),
                    label: Text(estado.etiqueta),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cargar(context, juego),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(T.cargarPartida),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _accion(BuildContext context, EstadoJuego juego, String accion) async {
    switch (accion) {
      case 'cargar':
        await _cargar(context, juego);
        return;
      case 'contenido':
        try {
          final contenido = await juego.contenido(guardada);
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(guardada.nombre, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: double.maxFinite,
                height: 460,
                child: VisorCodigo(nombre: guardada.nombre, contenido: contenido),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text(T.cerrar)),
              ],
            ),
          );
        } catch (e) {
          if (context.mounted) _aviso(context, '$e');
        }
        return;
      case 'exportar':
        try {
          final bytes = await guardada.archivo.readAsBytes();
          final uri = await FilePicker.saveFile(
            fileName: guardada.nombre,
            bytes: bytes,
            mimeType: _mime(guardada.nombre),
          );
          if (uri != null && context.mounted) _aviso(context, 'Partida exportada.');
        } catch (e) {
          if (context.mounted) _aviso(context, '$e');
        }
        return;
      case 'compartir':
        try {
          await SharePlus.instance.share(ShareParams(
            files: [XFile(guardada.archivo.path)],
            text: 'Partida de Pares Politécnicos: ${guardada.nombre}',
          ));
        } catch (e) {
          if (context.mounted) _aviso(context, '$e');
        }
        return;
      case 'etiqueta':
        await _editarEtiqueta(context, juego);
        return;
      case 'eliminar':
        final confirmar = await confirmarAccion(
          context,
          titulo: '${T.eliminar} ${guardada.nombre}',
          mensaje: 'La partida se eliminará de forma permanente. Las demás no se modifican.',
          textoConfirmar: T.eliminar,
          destructivo: true,
        );
        if (!confirmar) return;
        await juego.eliminar(guardada);
        return;
    }
  }

  Future<void> _cargar(BuildContext context, EstadoJuego juego) async {
    try {
      await juego.cargar(guardada);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PantallaJuego()),
      );
    } catch (e) {
      if (context.mounted) _aviso(context, '$e');
    }
  }

  Future<void> _editarEtiqueta(BuildContext context, EstadoJuego juego) async {
    final controlador = TextEditingController(text: guardada.estado?.etiqueta ?? '');
    final etiqueta = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text(T.etiqueta),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(labelText: T.etiqueta),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text(T.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, controlador.text.trim()),
            child: const Text(T.guardar),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (etiqueta == null || !context.mounted) return;
    try {
      await juego.actualizarEtiqueta(guardada, etiqueta);
    } catch (e) {
      if (context.mounted) _aviso(context, '$e');
    }
  }

  String _mime(String nombre) {
    if (nombre.endsWith('.json')) return 'application/json';
    if (nombre.endsWith('.xml')) return 'application/xml';
    return 'text/plain';
  }

  static void _aviso(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14),
        const SizedBox(width: 4),
        Text(texto, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
