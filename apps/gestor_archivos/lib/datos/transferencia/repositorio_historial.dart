import 'dart:io';

import '../../dominio/transferencia/historial_transferencias.dart';

/// Persistencia atómica del historial (escribe a `.tmp` y renombra).
class RepositorioHistorial {
  RepositorioHistorial(this.archivo);

  final File archivo;

  /// Carga aplicando la regla de reinicio y, si hubo cambios, los persiste.
  Future<HistorialTransferencias> cargar() async {
    HistorialTransferencias h;
    try {
      if (!archivo.existsSync()) return HistorialTransferencias();
      h = HistorialTransferencias.desdeTexto(await archivo.readAsString());
    } catch (_) {
      return HistorialTransferencias();
    }
    if (h.aplicarReinicio() > 0) await guardar(h);
    return h;
  }

  Future<void> guardar(HistorialTransferencias h) async {
    try {
      await archivo.parent.create(recursive: true);
      final tmp = File('${archivo.path}.tmp');
      await tmp.writeAsString(h.toJsonTexto(), flush: true);
      await tmp.rename(archivo.path);
    } catch (_) {
      // El historial es informativo: un fallo de escritura no debe romper la app.
    }
  }
}
