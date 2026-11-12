import 'dart:convert';

import 'estado_transferencia.dart';
import 'registro_transferencia.dart';

/// Historial persistido en JSON.
class HistorialTransferencias {
  HistorialTransferencias([List<RegistroTransferencia>? registros])
      : registros = registros ?? <RegistroTransferencia>[];

  static const int maxRegistros = 100;
  static const String motivoReinicio = 'interrumpida por reinicio';

  /// Más recientes primero.
  final List<RegistroTransferencia> registros;

  /// Inserta o reemplaza por id (nuevos al inicio).
  void guardar(RegistroTransferencia r) {
    final i = registros.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      registros[i] = r;
    } else {
      registros.insert(0, r);
      if (registros.length > maxRegistros) {
        registros.removeRange(maxRegistros, registros.length);
      }
    }
  }

  /// Regla de reinicio: `enCurso`/`pendiente` huérfanos pasan a `fallido`.
  /// Devuelve cuántos cambió.
  int aplicarReinicio({DateTime? ahora}) {
    var n = 0;
    for (var i = 0; i < registros.length; i++) {
      final r = registros[i];
      if (!r.estado.esFinal) {
        registros[i] = r.conEstado(EstadoTransferencia.fallido,
            motivo: motivoReinicio, ahora: ahora);
        n++;
      }
    }
    return n;
  }

  String toJsonTexto() => jsonEncode(<String, dynamic>{
        'v': 1,
        'registros': registros.map((r) => r.toJson()).toList(),
      });

  /// Tolera JSON corrupto (devuelve historial vacío).
  factory HistorialTransferencias.desdeTexto(String texto, {bool reinicio = false}) {
    final h = HistorialTransferencias();
    try {
      final crudo = jsonDecode(texto);
      final lista = crudo is Map ? crudo['registros'] : crudo;
      if (lista is List) {
        for (final e in lista) {
          final r = RegistroTransferencia.desdeJson(e);
          if (r != null) h.registros.add(r);
        }
      }
    } catch (_) {}
    if (reinicio) h.aplicarReinicio();
    return h;
  }
}
