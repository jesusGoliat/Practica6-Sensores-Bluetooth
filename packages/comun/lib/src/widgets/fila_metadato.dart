import 'package:flutter/material.dart';

/// Fila etiqueta/valor para las hojas de metadatos.
class FilaMetadato extends StatelessWidget {
  const FilaMetadato({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.icono,
  });

  final String etiqueta;
  final String valor;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 18, color: esquema.primary),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 112,
            child: Text(
              etiqueta,
              style: TextStyle(
                color: esquema.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
