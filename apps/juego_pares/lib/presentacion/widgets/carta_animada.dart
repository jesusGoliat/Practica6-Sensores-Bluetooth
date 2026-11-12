import 'package:flutter/material.dart';

import '../../dominio/carta.dart';
import '../../dominio/simbolos.dart';

/// Carta con volteo animado y etiqueta de accesibilidad.
class CartaAnimada extends StatelessWidget {
  const CartaAnimada({
    super.key,
    required this.carta,
    required this.indice,
    required this.alTocar,
    required this.animaciones,
  });

  final Carta carta;
  final int indice;
  final VoidCallback alTocar;
  final bool animaciones;

  @override
  Widget build(BuildContext context) {
    final visible = carta.estado != EstadoCarta.oculta;
    final emparejada = carta.estado == EstadoCarta.emparejada;
    final simbolo = simboloPorId(carta.simboloId);
    final esquema = Theme.of(context).colorScheme;
    final duracion = animaciones ? const Duration(milliseconds: 260) : Duration.zero;

    final etiqueta = emparejada
        ? 'Carta ${indice + 1}, emparejada, ${simbolo.etiqueta}'
        : visible
            ? 'Carta ${indice + 1}, visible, ${simbolo.etiqueta}'
            : 'Carta ${indice + 1}, oculta';

    return Semantics(
      button: true,
      label: etiqueta,
      child: GestureDetector(
        key: Key('carta-$indice'),
        onTap: emparejada ? null : alTocar,
        child: AnimatedSwitcher(
          duration: duracion,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final giro = Tween<double>(begin: 0.65, end: 1).animate(animation);
            return ScaleTransition(scale: giro, child: child);
          },
          child: visible
              ? Container(
                  key: ValueKey('frente-${carta.simboloId}-$emparejada'),
                  decoration: BoxDecoration(
                    color: emparejada
                        ? simbolo.categoria.color.withValues(alpha: 0.75)
                        : simbolo.categoria.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: emparejada ? esquema.tertiary : Colors.white24,
                      width: emparejada ? 3 : 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(simbolo.icono, color: Colors.white, size: 44),
                        ),
                      ),
                      if (emparejada)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.check_circle, color: esquema.tertiary, size: 18),
                        ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('dorso'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [esquema.primary, esquema.primary.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.help_outline,
                          color: esquema.onPrimary.withValues(alpha: 0.85),
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
