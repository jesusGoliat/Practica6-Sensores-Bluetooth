import 'dart:math';

import 'package:flutter/material.dart';

/// Confeti sencillo dibujado con CustomPainter, sin dependencias externas.
class Confeti extends StatefulWidget {
  const Confeti({super.key, this.activo = true});

  final bool activo;

  @override
  State<Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<Confeti> with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activo) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _control,
        builder: (context, _) => CustomPaint(
          painter: _ConfetiPainter(_control.value, Theme.of(context).colorScheme),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfetiPainter extends CustomPainter {
  _ConfetiPainter(this.progreso, this.esquema);
  final double progreso;
  final ColorScheme esquema;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    final colores = <Color>[
      esquema.primary,
      esquema.secondary,
      esquema.tertiary,
      esquema.error,
      Colors.amber,
    ];
    for (var i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final desfase = random.nextDouble();
      final t = (progreso + desfase) % 1.0;
      final y = t * (size.height + 80) - 40;
      final tamano = 5 + random.nextDouble() * 7;
      final color = colores[random.nextInt(colores.length)];
      final paint = Paint()..color = color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 8 + desfase * 5);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: tamano, height: tamano * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfetiPainter oldDelegate) => oldDelegate.progreso != progreso;
}
