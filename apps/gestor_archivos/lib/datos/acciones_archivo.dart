import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../dominio/error_archivo.dart';
import '../dominio/modelos.dart';
import 'servicio_archivos.dart';

/// Acciones que delegan en el sistema operativo: compartir, exportar y abrir
/// con otra aplicación. Primero copian el contenido a la caché de la app, de
/// modo que funcionan igual con una ruta privada o un URI de SAF.
class AccionesArchivo {
  AccionesArchivo(this._cache);

  final Directory _cache;

  Future<File> copiarACache(EntradaArchivo entrada, ServicioArchivos servicio) async {
    try {
      final bytes = await servicio.leer(entrada, maxBytes: 80 * 1024 * 1024);
      final carpeta = Directory(p.join(_cache.path, 'compartir'));
      await carpeta.create(recursive: true);
      final archivo = File(p.join(
        carpeta.path,
        '${DateTime.now().microsecondsSinceEpoch}-${entrada.nombre}',
      ));
      await archivo.writeAsBytes(bytes, flush: true);
      return archivo;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  Future<void> compartir(
    EntradaArchivo entrada,
    ServicioArchivos servicio, {
    Rect? origen,
  }) async {
    final archivo = await copiarACache(entrada, servicio);
    await SharePlus.instance.share(ShareParams(
      files: <XFile>[XFile(archivo.path)],
      text: entrada.nombre,
      sharePositionOrigin: origen,
    ));
  }

  Future<bool> exportar(EntradaArchivo entrada, ServicioArchivos servicio) async {
    final bytes = await servicio.leer(entrada, maxBytes: 80 * 1024 * 1024);
    final uri = await FilePicker.saveFile(
      fileName: entrada.nombre,
      bytes: bytes,
      mimeType: entrada.mime ?? 'application/octet-stream',
      dialogTitle: 'Exportar ${entrada.nombre}',
    );
    return uri != null;
  }

  Future<String?> abrirCon(EntradaArchivo entrada, ServicioArchivos servicio) async {
    final archivo = await copiarACache(entrada, servicio);
    final resultado = await OpenFilex.open(archivo.path);
    if (resultado.type == ResultType.done) return null;
    return resultado.message.isEmpty
        ? 'No hay una aplicación disponible para abrir este formato.'
        : resultado.message;
  }

  Future<bool> guardarBytes(String nombre, Uint8List bytes, String mime) async {
    final uri = await FilePicker.saveFile(
      fileName: nombre,
      bytes: bytes,
      mimeType: mime,
    );
    return uri != null;
  }
}
