import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda la partida de red en `partida_red.json` (escritura atómica).
class RepositorioPartidaRed {
  RepositorioPartidaRed(this._archivo);

  /// En una carpeta concreta (pruebas).
  RepositorioPartidaRed.enDirectorio(Directory dir)
      : this(() async {
          await dir.create(recursive: true);
          return File(p.join(dir.path, nombreArchivo));
        });

  /// En el directorio de documentos de la app (resuelto al primer uso).
  RepositorioPartidaRed.documentos()
      : this(() async {
          final d = await getApplicationDocumentsDirectory();
          return File(p.join(d.path, nombreArchivo));
        });

  static const String nombreArchivo = 'partida_red.json';
  final Future<File> Function() _archivo;

  Future<void> guardar(Map<String, Object?> json) async {
    final destino = await _archivo();
    final temporal = File('${destino.path}.tmp');
    await temporal.writeAsString(jsonEncode(json), flush: true);
    try {
      await temporal.rename(destino.path);
    } on FileSystemException {
      if (await destino.exists()) await destino.delete();
      await temporal.rename(destino.path);
    }
  }

  /// `null` si no hay archivo o está dañado (se elimina).
  Future<Map<String, Object?>?> cargar() async {
    final f = await _archivo();
    if (!await f.exists()) return null;
    try {
      final crudo = jsonDecode(await f.readAsString());
      if (crudo is Map) return Map<String, Object?>.from(crudo);
    } catch (_) {}
    try {
      await f.delete();
    } catch (_) {}
    return null;
  }

  Future<void> borrar() async {
    final f = await _archivo();
    if (await f.exists()) await f.delete();
  }
}
