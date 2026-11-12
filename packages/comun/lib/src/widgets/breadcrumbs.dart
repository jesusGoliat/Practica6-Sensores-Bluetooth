import 'package:flutter/material.dart';

/// Un segmento de la ruta visible. El último suele no ser navegable.
class Migaja {
  const Migaja(this.etiqueta, {this.alTocar, this.icono});
  final String etiqueta;
  final VoidCallback? alTocar;
  final IconData? icono;
}

/// Breadcrumbs desplazables horizontalmente para rutas largas.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.migajas, this.prefijo});

  final List<Migaja> migajas;
  final Widget? prefijo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          ?prefijo,
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (var i = 0; i < migajas.length; i++) ...[
                    if (i > 0)
                      Icon(Icons.chevron_right, size: 18, color: esquema.outline),
                    if (migajas[i].alTocar == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        child: Text(
                          migajas[i].etiqueta,
                          style: TextStyle(
                            color: esquema.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: migajas[i].alTocar,
                        icon: Icon(migajas[i].icono ?? Icons.folder_outlined, size: 18),
                        label: Text(migajas[i].etiqueta),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
