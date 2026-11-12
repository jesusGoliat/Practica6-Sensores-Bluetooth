import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/estado_tema.dart';

/// Selector de los dos temas institucionales y del modo claro/oscuro.
class DialogoTema extends StatelessWidget {
  const DialogoTema({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<EstadoTema>();
    return AlertDialog(
      title: const Text(T.tema),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${T.apariencia}: ${tema.nombreVisual}',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text(T.temaGuinda),
                  selected: tema.visual == TemaVisual.guinda,
                  onSelected: (_) => tema.cambiarVisual(TemaVisual.guinda),
                ),
                ChoiceChip(
                  label: const Text(T.temaAzul),
                  selected: tema.visual == TemaVisual.azul,
                  onSelected: (_) => tema.cambiarVisual(TemaVisual.azul),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Modo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(T.modoSistema),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(T.modoClaro),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(T.modoOscuro),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {tema.modo},
              onSelectionChanged: (valores) => tema.cambiarModo(valores.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(T.listo),
        ),
      ],
    );
  }
}

/// Muestra un SnackBar para errores de operaciones.
void avisarError(BuildContext context, Object error) {
  final mensaje = error is Exception ? error.toString() : '$error';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Evita que una excepción de archivo se convierta en pantalla roja.
Future<void> ejecutarSeguro(BuildContext context, Future<void> Function() accion) async {
  try {
    await accion();
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}
