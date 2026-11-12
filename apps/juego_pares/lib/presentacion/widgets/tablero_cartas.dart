import 'package:flutter/material.dart';

import '../../dominio/carta.dart';
import 'carta_animada.dart';

/// Tablero cuadrado de cartas con cursor opcional (control por movimiento).
class TableroCartas extends StatelessWidget {
  const TableroCartas({
    super.key,
    required this.cartas,
    required this.filas,
    required this.columnas,
    required this.animaciones,
    required this.alTocar,
    this.cursor,
  });

  final List<Carta> cartas;
  final int filas;
  final int columnas;
  final bool animaciones;
  final void Function(int indice) alTocar;
  final int? cursor;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 6.0;
        final maxAncho = constraints.maxWidth - 24;
        final maxAlto = constraints.maxHeight - 12;
        final anchoCelda = (maxAncho - (columnas - 1) * separacion) / columnas;
        final altoCelda = (maxAlto - (filas - 1) * separacion) / filas;
        final lado = anchoCelda < altoCelda ? anchoCelda : altoCelda;
        final ancho = lado * columnas + (columnas - 1) * separacion;
        final alto = lado * filas + (filas - 1) * separacion;
        return Center(
          child: SizedBox(
            width: ancho.clamp(0, maxAncho),
            height: alto.clamp(0, maxAlto),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                mainAxisSpacing: separacion,
                crossAxisSpacing: separacion,
              ),
              itemCount: cartas.length,
              itemBuilder: (context, i) {
                final carta = CartaAnimada(
                  carta: cartas[i],
                  indice: i,
                  animaciones: animaciones,
                  alTocar: () => alTocar(i),
                );
                if (cursor != i) return carta;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    carta,
                    Positioned.fill(
                      child: Semantics(
                        label: 'Cursor de movimiento sobre la carta ${i + 1}',
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: const Key('cursor-movimiento'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: esquema.tertiary, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
