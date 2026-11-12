import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../dominio/modelos.dart';

/// Genera y conserva miniaturas en disco para que la cuadrícula no decodifique
/// la imagen completa cada vez que se reconstruye.
class CacheMiniaturas {
  CacheMiniaturas(Directory base) : _directorio = Directory(p.join(base.path, 'miniaturas'));

  final Directory _directorio;
  static const int _maxBytes = 40 * 1024 * 1024;
  static const int _maxArchivos = 300;

  Future<Uint8List?> obtener(
    EntradaArchivo entrada, {
    required Future<Uint8List> Function() leer,
  }) async {
    final clave = sha1
        .convert('${entrada.clave}|${entrada.tamano ?? 0}|${entrada.modificado?.millisecondsSinceEpoch ?? 0}'
            .codeUnits)
        .toString();
    final archivo = File(p.join(_directorio.path, '$clave.jpg'));
    try {
      if (await archivo.exists()) {
        // "Tocar" el archivo conserva el criterio LRU aproximado.
        await archivo.setLastModified(DateTime.now());
        return await archivo.readAsBytes();
      }
      final originales = await leer();
      final miniatura = await compute(_generar, <String, Object?>{
        'bytes': originales,
        'lado': 320,
      });
      if (miniatura == null || miniatura.isEmpty) return null;
      await _directorio.create(recursive: true);
      await archivo.writeAsBytes(miniatura, flush: true);
      await _podar();
      return miniatura;
    } catch (_) {
      // Una imagen dañada o un proveedor sin lectura no debe tumbar la lista.
      return null;
    }
  }

  Future<void> limpiar() async {
    if (!await _directorio.exists()) return;
    await for (final entidad in _directorio.list()) {
      try {
        await entidad.delete(recursive: true);
      } catch (_) {
        // Ignorar archivos que el sistema tenga abiertos.
      }
    }
  }

  Future<int> tamanoBytes() async {
    if (!await _directorio.exists()) return 0;
    var total = 0;
    await for (final entidad in _directorio.list()) {
      if (entidad is File) {
        try {
          total += await entidad.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> _podar() async {
    if (!await _directorio.exists()) return;
    final archivos = <File>[];
    await for (final entidad in _directorio.list()) {
      if (entidad is File) archivos.add(entidad);
    }
    final datos = <(File, FileStat)>[];
    for (final archivo in archivos) {
      try {
        datos.add((archivo, await archivo.stat()));
      } catch (_) {}
    }
    datos.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var total = datos.fold<int>(0, (suma, item) => suma + item.$2.size);
    var cantidad = datos.length;
    for (final (archivo, stat) in datos) {
      if (total <= _maxBytes && cantidad <= _maxArchivos) break;
      try {
        await archivo.delete();
        total -= stat.size;
        cantidad--;
      } catch (_) {}
    }
  }
}

/// Función de nivel superior para ejecutarse en un isolate.
Uint8List? _generar(Map<String, Object?> args) {
  final bytes = args['bytes'] as Uint8List?;
  final lado = args['lado'] as int? ?? 320;
  if (bytes == null || bytes.isEmpty) return null;
  final original = img.decodeImage(bytes);
  if (original == null) return null;
  final orientada = img.bakeOrientation(original);
  final escala = lado / (orientada.width > orientada.height ? orientada.width : orientada.height);
  final ancho = (orientada.width * escala).round().clamp(1, lado);
  final alto = (orientada.height * escala).round().clamp(1, lado);
  final reducida = img.copyResize(orientada, width: ancho, height: alto, interpolation: img.Interpolation.average);
  return Uint8List.fromList(img.encodeJpg(reducida, quality: 82));
}
