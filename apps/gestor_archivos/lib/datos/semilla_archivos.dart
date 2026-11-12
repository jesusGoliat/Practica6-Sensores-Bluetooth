import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'repositorio_ubicaciones.dart';

/// Crea archivos de ejemplo en el espacio privado la primera vez que se abre
/// la app, para poder demostrar todos los visores sin pedir permisos.
class SemillaArchivos {
  SemillaArchivos(this._documentos);

  final Directory _documentos;

  static const _archivos = <String>[
    'bienvenida.txt',
    'notas.md',
    'datos.json',
    'configuracion.xml',
    'datos_invalidos.json',
    'muestra.xyz',
    'paisaje_escom.png',
  ];

  Future<void> crearSiFalta(PreferenciasApp prefs) async {
    if (prefs.semillaCreada) return;
    try {
      final ejemplos = Directory(p.join(_documentos.path, 'Ejemplos'));
      await ejemplos.create(recursive: true);
      for (final nombre in _archivos) {
        final destino = File(p.join(ejemplos.path, nombre));
        if (await destino.exists()) continue;
        final datos = await rootBundle.load('assets/demo/$nombre');
        await destino.writeAsBytes(datos.buffer.asUint8List(), flush: true);
      }
      final subcarpeta = Directory(p.join(ejemplos.path, 'Documentos IPN'));
      await subcarpeta.create(recursive: true);
      final acta = File(p.join(subcarpeta.path, 'acta.txt'));
      if (!await acta.exists()) {
        await acta.writeAsString(
          'Acta de ejemplo\n\n'
          'Este archivo vive en una subcarpeta para probar los breadcrumbs,\n'
          'la vista de árbol y las operaciones de copiar/mover/renombrar.\n',
          flush: true,
        );
      }
      await prefs.marcarSemillaCreada();
    } catch (_) {
      // Si falla la siembra, la app sigue funcionando con el espacio vacío.
    }
  }
}
