import 'package:flutter/material.dart';

import '../../dominio/transferencia/estado_transferencia.dart';

/// Estado de una transferencia: color + icono + texto (no depende solo del color).
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.estado, {super.key});

  final EstadoTransferencia estado;

  static (IconData, MaterialColor) _estilo(EstadoTransferencia e) => switch (e) {
        EstadoTransferencia.pendiente => (Icons.schedule, Colors.blueGrey),
        EstadoTransferencia.enCurso => (Icons.sync, Colors.blue),
        EstadoTransferencia.completado => (Icons.check_circle, Colors.green),
        EstadoTransferencia.cancelado => (Icons.cancel, Colors.orange),
        EstadoTransferencia.fallido => (Icons.error, Colors.red),
      };

  @override
  Widget build(BuildContext context) {
    final (icono, base) = _estilo(estado);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final texto = oscuro ? base.shade200 : base.shade900;
    return Semantics(
      label: 'Estado: ${estado.etiqueta}',
      excludeSemantics: true,
      child: Container(
        key: Key('chip-${estado.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: base.withValues(alpha: oscuro ? 0.25 : 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: base.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 16, color: texto),
          const SizedBox(width: 4),
          Text(estado.etiqueta,
              style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
