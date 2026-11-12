import 'dart:io';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_gestor.dart';
import '../datos/estado_tema.dart';
import '../dominio/modelos.dart';
import 'widgets/dialogo_tema.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<EstadoTema>();
    final gestor = context.watch<EstadoGestor>();
    final documentos = context.read<Directory>();
    final esquema = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('ajustes-tema-guinda'),
              label: const Text(T.temaGuinda),
              selected: tema.visual == TemaVisual.guinda,
              onSelected: (_) => tema.cambiarVisual(TemaVisual.guinda),
            ),
            ChoiceChip(
              key: const Key('ajustes-tema-azul'),
              label: const Text(T.temaAzul),
              selected: tema.visual == TemaVisual.azul,
              onSelected: (_) => tema.cambiarVisual(TemaVisual.azul),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text(T.modoSistema), icon: Icon(Icons.brightness_auto)),
            ButtonSegment(value: ThemeMode.light, label: Text(T.modoClaro), icon: Icon(Icons.light_mode)),
            ButtonSegment(value: ThemeMode.dark, label: Text(T.modoOscuro), icon: Icon(Icons.dark_mode)),
          ],
          selected: {tema.modo},
          onSelectionChanged: (valores) => tema.cambiarModo(valores.first),
        ),
        const Divider(height: 32),
        Text('Almacenamiento', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espacio privado de la app',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(
                  documentos.path,
                  style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: gestor.tamanoCache(),
          builder: (context, snapshot) {
            final tamano = Formato.bytes(snapshot.data ?? 0);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(T.cacheMiniaturas),
              subtitle: Text('$tamano en caché temporal'),
              trailing: TextButton(
                key: const Key('ajustes-limpiar-cache'),
                onPressed: () async {
                  await gestor.limpiarCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Caché de miniaturas vaciada.')),
                    );
                  }
                },
                child: const Text('Vaciar'),
              ),
            );
          },
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: Text('Carpetas autorizadas', style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: () async {
                try {
                  final raiz = await gestor.anadirCarpetaExterna();
                  if (raiz != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Carpeta autorizada: ${raiz.nombre}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) avisarError(context, e);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text(T.anadirCarpeta),
            ),
          ],
        ),
        for (final raiz in gestor.raices.where((r) => r.origen != OrigenArchivo.privado))
          Card(
            child: ListTile(
              leading: Icon(
                raiz.disponible ? Icons.folder_shared_outlined : Icons.folder_off_outlined,
                color: raiz.disponible ? null : esquema.error,
              ),
              title: Text(raiz.nombre),
              subtitle: Text(
                raiz.disponible ? raiz.origen.etiqueta : T.permisoRevocado,
                style: TextStyle(color: raiz.disponible ? null : esquema.error),
              ),
              trailing: IconButton(
                tooltip: 'Quitar autorización',
                onPressed: () async {
                  final confirmar = await confirmarAccion(
                    context,
                    titulo: 'Quitar autorización',
                    mensaje: 'La app dejará de ver «${raiz.nombre}». Los archivos no se borran.',
                    textoConfirmar: 'Quitar',
                    destructivo: true,
                  );
                  if (confirmar) await gestor.quitarRaiz(raiz);
                },
                icon: const Icon(Icons.link_off),
              ),
            ),
          ),
        if (gestor.raices.every((r) => r.origen == OrigenArchivo.privado))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aún no has autorizado carpetas externas. La app solo ve su espacio privado.',
              style: TextStyle(color: esquema.onSurfaceVariant),
            ),
          ),
        const Divider(height: 32),
        Text(T.acercaDe, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.apps),
          title: Text(T.appGestor),
          subtitle: Text('Práctica 4 · Flutter · Android e iOS · 100 % offline'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.memory),
          title: const Text('Plataforma'),
          subtitle: Text(Platform.operatingSystem),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.verified_outlined),
          title: Text('Versión'),
          subtitle: Text('1.0.0'),
        ),
      ],
    );
  }
}
