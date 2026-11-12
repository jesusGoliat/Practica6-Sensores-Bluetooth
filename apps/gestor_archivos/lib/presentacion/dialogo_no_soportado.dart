import 'package:comun/comun.dart';
import 'package:flutter/material.dart';

import '../dominio/modelos.dart';

enum AccionNoSoportada { abrir, compartir, exportar }

/// Diálogo para formatos sin visor interno: abrir con otra app, compartir o
/// exportar mediante las funciones del sistema operativo.
Future<AccionNoSoportada?> mostrarDialogoNoSoportado(
  BuildContext context,
  EntradaArchivo entrada,
) {
  final tipo = MapaTipos.tipoDe(entrada.nombre);
  return showDialog<AccionNoSoportada>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: const Icon(Icons.insert_drive_file_outlined),
      title: Text(entrada.nombre),
      content: Text(
        'Este formato (${tipo.descripcion}) no tiene un visor interno. '
        'Puedes abrirlo con otra aplicación, compartirlo o guardar una copia '
        'en una ubicación que elijas.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text(T.cancelar),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pop(contexto, AccionNoSoportada.abrir),
          icon: const Icon(Icons.open_in_new),
          label: const Text(T.abrirCon),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pop(contexto, AccionNoSoportada.compartir),
          icon: const Icon(Icons.share_outlined),
          label: const Text(T.compartir),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(contexto, AccionNoSoportada.exportar),
          icon: const Icon(Icons.save_alt),
          label: const Text(T.exportar),
        ),
      ],
    ),
  );
}
