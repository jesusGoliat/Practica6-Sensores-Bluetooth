import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_gestor.dart';
import 'widgets/lista_guardados.dart';

class PantallaRecientes extends StatelessWidget {
  const PantallaRecientes({super.key});

  @override
  Widget build(BuildContext context) {
    final gestor = context.watch<EstadoGestor>();
    if (gestor.recientes.isEmpty) {
      return const EstadoVacio(
        icono: Icons.history,
        titulo: T.sinRecientes,
        mensaje: 'Los archivos que abras aparecerán aquí, aunque cierres y vuelvas a abrir la app.',
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () async {
                final confirmar = await confirmarAccion(
                  context,
                  titulo: 'Limpiar recientes',
                  mensaje: '¿Quieres vaciar el historial de archivos recientes?',
                  textoConfirmar: 'Limpiar',
                  destructivo: true,
                );
                if (confirmar) {
                  for (final entrada in List.of(gestor.recientes)) {
                    await gestor.quitarReciente(entrada);
                  }
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Limpiar historial'),
            ),
          ),
        ),
        Expanded(
          child: ListaGuardados(
            entradas: gestor.recientes,
            textoQuitar: 'Quitar de recientes',
            alQuitar: (entrada) => gestor.quitarReciente(entrada),
          ),
        ),
      ],
    );
  }
}
