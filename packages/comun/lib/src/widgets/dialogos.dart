import 'package:flutter/material.dart';

/// Confirmación explícita para acciones destructivas o que sobrescriben datos.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  bool destructivo = false,
}) async {
  final esquema = Theme.of(context).colorScheme;
  final resultado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: Icon(
        destructivo ? Icons.warning_amber_rounded : Icons.help_outline,
        color: destructivo ? esquema.error : esquema.primary,
      ),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructivo
              ? FilledButton.styleFrom(
                  backgroundColor: esquema.error,
                  foregroundColor: esquema.onError,
                )
              : null,
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return resultado ?? false;
}

/// Aviso simple con un solo botón.
Future<void> mostrarAviso(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String boton = 'Entendido',
}) {
  return showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(contexto),
          child: Text(boton),
        ),
      ],
    ),
  );
}
