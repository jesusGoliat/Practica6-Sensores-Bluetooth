import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';

import '../dominio/error_archivo.dart';
import '../dominio/modelos.dart';
import '../dominio/validador_rutas.dart';
import 'package:comun/comun.dart';

/// Contrato común para el espacio privado, SAF (Android) y iOS.
abstract class ServicioArchivos {
  OrigenArchivo get origen;

  Future<List<EntradaArchivo>> listar(RaizAutorizada raiz, String referencia);
  Future<EntradaArchivo?> info(RaizAutorizada raiz, String referencia, {String? nombre});
  Future<Uint8List> leer(EntradaArchivo entrada, {int maxBytes = 60 * 1024 * 1024});
  Future<void> escribir(
    RaizAutorizada raiz,
    String carpetaRef,
    String nombre,
    Uint8List bytes, {
    bool sobrescribir = false,
  });
  Future<void> crearCarpeta(RaizAutorizada raiz, String carpetaRef, String nombre);
  Future<void> renombrar(
    EntradaArchivo entrada,
    String carpetaPadreRef,
    String nuevoNombre, {
    bool sobrescribir = false,
  });
  Future<void> copiar(EntradaArchivo entrada, RaizAutorizada destinoRaiz, String destinoRef, {bool sobrescribir = false});
  Future<void> mover(EntradaArchivo entrada, RaizAutorizada destinoRaiz, String destinoRef, {bool sobrescribir = false});
  Future<void> eliminar(EntradaArchivo entrada);
  Future<bool> existe(RaizAutorizada raiz, String referencia);
}

/// Implementación con dart:io para el espacio privado y para las carpetas
/// externas de iOS (mientras el security scope esté abierto).
class ServicioRutas implements ServicioArchivos {
  ServicioRutas({required this.origen});

  @override
  final OrigenArchivo origen;

  EntradaArchivo _entrada(FileSystemEntity entidad, RaizAutorizada raiz) {
    final nombre = p.basename(entidad.path);
    final tipo = MapaTipos.tipoDe(nombre);
    final esCarpeta = entidad is Directory;
    FileStat? stat;
    try {
      stat = entidad.statSync();
    } on FileSystemException {
      stat = null;
    }
    return EntradaArchivo(
      nombre: nombre,
      referencia: entidad.path,
      esCarpeta: esCarpeta,
      origen: origen,
      raiz: raiz,
      tamano: esCarpeta ? null : stat?.size,
      modificado: stat?.modified,
      creado: null,
      mime: esCarpeta ? null : tipo.mime,
      utType: esCarpeta || tipo.utType.isEmpty ? null : tipo.utType,
      soloLectura: raiz.soloLectura,
    );
  }

  void _validar(RaizAutorizada raiz, String referencia) {
    ValidadorRutas.exigirDentroDe(referencia, raiz.referencia);
  }

  @override
  Future<List<EntradaArchivo>> listar(RaizAutorizada raiz, String referencia) async {
    try {
      _validar(raiz, referencia);
      final directorio = Directory(referencia);
      if (!directorio.existsSync()) {
        throw const ErrorArchivo(TipoErrorArchivo.noEncontrado, 'La carpeta ya no existe.');
      }
      final entradas = <EntradaArchivo>[];
      for (final entidad in directorio.listSync(followLinks: false)) {
        try {
          entradas.add(_entrada(entidad, raiz));
        } on FileSystemException {
          // Un archivo ilegible no debe impedir listar el resto de la carpeta.
        }
      }
      entradas.sort((a, b) {
        if (a.esCarpeta != b.esCarpeta) return a.esCarpeta ? -1 : 1;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
      return entradas;
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<EntradaArchivo?> info(RaizAutorizada raiz, String referencia, {String? nombre}) async {
    try {
      _validar(raiz, referencia);
      final tipo = FileSystemEntity.typeSync(referencia, followLinks: false);
      if (tipo == FileSystemEntityType.notFound) return null;
      final entidad = tipo == FileSystemEntityType.directory ? Directory(referencia) : File(referencia);
      return _entrada(entidad, raiz);
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<Uint8List> leer(EntradaArchivo entrada, {int maxBytes = 60 * 1024 * 1024}) async {
    try {
      _validar(entrada.raiz, entrada.referencia);
      final archivo = File(entrada.referencia);
      if (!archivo.existsSync()) {
        throw const ErrorArchivo(TipoErrorArchivo.noEncontrado, 'El archivo ya no existe.');
      }
      final tamano = archivo.lengthSync();
      if (tamano > maxBytes) {
        throw ErrorArchivo(
          TipoErrorArchivo.lectura,
          'El archivo pesa ${Formato.bytes(tamano)} y supera el límite de vista previa (${Formato.bytes(maxBytes)}). Puedes exportarlo o compartirlo.',
        );
      }
      return await archivo.readAsBytes();
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  String _destino(RaizAutorizada raiz, String carpetaRef, String nombre) {
    _validar(raiz, carpetaRef);
    final destino = ValidadorRutas.unirSeguro(carpetaRef, nombre);
    return destino;
  }

  @override
  Future<void> escribir(
    RaizAutorizada raiz,
    String carpetaRef,
    String nombre,
    Uint8List bytes, {
    bool sobrescribir = false,
  }) async {
    try {
      final destino = _destino(raiz, carpetaRef, nombre);
      final archivo = File(destino);
      if (archivo.existsSync() && !sobrescribir) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un archivo con ese nombre.');
      }
      archivo.parent.createSync(recursive: true);
      await archivo.writeAsBytes(bytes, flush: true);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> crearCarpeta(RaizAutorizada raiz, String carpetaRef, String nombre) async {
    try {
      final destino = _destino(raiz, carpetaRef, nombre);
      final directorio = Directory(destino);
      if (directorio.existsSync()) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe una carpeta con ese nombre.');
      }
      await directorio.create();
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> renombrar(
    EntradaArchivo entrada,
    String carpetaPadreRef,
    String nuevoNombre, {
    bool sobrescribir = false,
  }) async {
    try {
      ValidadorRutas.exigirNombreValido(nuevoNombre);
      _validar(entrada.raiz, carpetaPadreRef);
      final destino = ValidadorRutas.unirSeguro(carpetaPadreRef, nuevoNombre);
      if (destino == entrada.referencia) return;
      if (FileSystemEntity.typeSync(destino) != FileSystemEntityType.notFound && !sobrescribir) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre.');
      }
      if (sobrescribir && FileSystemEntity.typeSync(destino) != FileSystemEntityType.notFound) {
        await _borrarRuta(destino);
      }
      if (entrada.esCarpeta) {
        await Directory(entrada.referencia).rename(destino);
      } else {
        await File(entrada.referencia).rename(destino);
      }
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> copiar(
    EntradaArchivo entrada,
    RaizAutorizada destinoRaiz,
    String destinoRef, {
    bool sobrescribir = false,
  }) async {
    try {
      _validar(destinoRaiz, destinoRef);
      final destino = ValidadorRutas.unirSeguro(destinoRef, entrada.nombre);
      if (FileSystemEntity.typeSync(destino) != FileSystemEntityType.notFound) {
        if (!sobrescribir) {
          throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre en el destino.');
        }
        await _borrarRuta(destino);
      }
      await _copiarRuta(entrada.referencia, destino, entrada.esCarpeta);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> mover(
    EntradaArchivo entrada,
    RaizAutorizada destinoRaiz,
    String destinoRef, {
    bool sobrescribir = false,
  }) async {
    try {
      _validar(destinoRaiz, destinoRef);
      final destino = ValidadorRutas.unirSeguro(destinoRef, entrada.nombre);
      if (FileSystemEntity.typeSync(destino) != FileSystemEntityType.notFound) {
        if (!sobrescribir) {
          throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre en el destino.');
        }
        await _borrarRuta(destino);
      }
      try {
        if (entrada.esCarpeta) {
          await Directory(entrada.referencia).rename(destino);
        } else {
          await File(entrada.referencia).rename(destino);
        }
      } on FileSystemException {
        // Cambio de volumen/proveedor: copiar y luego borrar el origen.
        await _copiarRuta(entrada.referencia, destino, entrada.esCarpeta);
        await _borrarRuta(entrada.referencia);
      }
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> eliminar(EntradaArchivo entrada) async {
    try {
      _validar(entrada.raiz, entrada.referencia);
      if (entrada.referencia == entrada.raiz.referencia) {
        throw const ErrorArchivo(TipoErrorArchivo.noSoportado, 'No se puede eliminar la raíz autorizada.');
      }
      await _borrarRuta(entrada.referencia);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<bool> existe(RaizAutorizada raiz, String referencia) async {
    try {
      _validar(raiz, referencia);
      return FileSystemEntity.typeSync(referencia) != FileSystemEntityType.notFound;
    } catch (_) {
      return false;
    }
  }

  Future<void> _borrarRuta(String ruta) async {
    final tipo = FileSystemEntity.typeSync(ruta, followLinks: false);
    if (tipo == FileSystemEntityType.directory) {
      await Directory(ruta).delete(recursive: true);
    } else if (tipo != FileSystemEntityType.notFound) {
      await File(ruta).delete();
    }
  }

  Future<void> _copiarRuta(String origen, String destino, bool esCarpeta) async {
    if (!esCarpeta) {
      await File(origen).copy(destino);
      return;
    }
    await Directory(destino).create(recursive: true);
    await for (final entidad in Directory(origen).list(recursive: false, followLinks: false)) {
      final nombre = p.basename(entidad.path);
      final subDestino = p.join(destino, nombre);
      if (entidad is Directory) {
        await _copiarRuta(entidad.path, subDestino, true);
      } else if (entidad is File) {
        await entidad.copy(subDestino);
      }
    }
  }
}

/// Implementación Android basada en Storage Access Framework.
class ServicioSaf implements ServicioArchivos {
  ServicioSaf([Saf? saf]) : _saf = saf ?? Saf();

  final Saf _saf;

  @override
  OrigenArchivo get origen => OrigenArchivo.saf;

  EntradaArchivo _entrada(SafDocumentFile doc, RaizAutorizada raiz) {
    final tipo = MapaTipos.tipoDe(doc.name);
    return EntradaArchivo(
      nombre: doc.name,
      referencia: doc.uri,
      esCarpeta: doc.isDir,
      origen: OrigenArchivo.saf,
      raiz: raiz,
      tamano: doc.isDir ? null : doc.length,
      modificado: doc.lastModified > 0
          ? DateTime.fromMillisecondsSinceEpoch(doc.lastModified)
          : null,
      creado: null,
      mime: doc.mimeType ?? (doc.isDir ? null : tipo.mime),
      utType: doc.isDir || tipo.utType.isEmpty ? null : tipo.utType,
      soloLectura: raiz.soloLectura,
    );
  }

  @override
  Future<List<EntradaArchivo>> listar(RaizAutorizada raiz, String referencia) async {
    try {
      final docs = await _saf.list(referencia);
      final entradas = docs.map((d) => _entrada(d, raiz)).toList();
      entradas.sort((a, b) {
        if (a.esCarpeta != b.esCarpeta) return a.esCarpeta ? -1 : 1;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
      return entradas;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<EntradaArchivo?> info(RaizAutorizada raiz, String referencia, {String? nombre}) async {
    try {
      final doc = await _saf.stat(referencia);
      return doc == null ? null : _entrada(doc, raiz);
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<Uint8List> leer(EntradaArchivo entrada, {int maxBytes = 60 * 1024 * 1024}) async {
    try {
      final info = await _saf.stat(entrada.referencia);
      if (info == null) {
        throw const ErrorArchivo(TipoErrorArchivo.noEncontrado, 'El archivo ya no existe.');
      }
      if (info.length > maxBytes) {
        throw ErrorArchivo(
          TipoErrorArchivo.lectura,
          'El archivo pesa ${Formato.bytes(info.length)} y supera el límite de vista previa (${Formato.bytes(maxBytes)}). Puedes exportarlo o compartirlo.',
        );
      }
      return await _saf.readFileBytes(entrada.referencia);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> escribir(
    RaizAutorizada raiz,
    String carpetaRef,
    String nombre,
    Uint8List bytes, {
    bool sobrescribir = false,
  }) async {
    try {
      ValidadorRutas.exigirNombreValido(nombre);
      final existente = await _saf.child(carpetaRef, <String>[nombre]);
      if (existente != null && !sobrescribir) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un archivo con ese nombre.');
      }
      final tipo = MapaTipos.tipoDe(nombre);
      await _saf.writeFileBytes(carpetaRef, nombre, tipo.mime, bytes, overwrite: sobrescribir);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> crearCarpeta(RaizAutorizada raiz, String carpetaRef, String nombre) async {
    try {
      ValidadorRutas.exigirNombreValido(nombre);
      final existente = await _saf.child(carpetaRef, <String>[nombre]);
      if (existente != null) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe una carpeta con ese nombre.');
      }
      await _saf.mkdirp(carpetaRef, <String>[nombre]);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> renombrar(
    EntradaArchivo entrada,
    String carpetaPadreRef,
    String nuevoNombre, {
    bool sobrescribir = false,
  }) async {
    try {
      ValidadorRutas.exigirNombreValido(nuevoNombre);
      final existente = await _saf.child(carpetaPadreRef, <String>[nuevoNombre]);
      if (existente != null && existente.uri != entrada.referencia && !sobrescribir) {
        throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre.');
      }
      if (existente != null && existente.uri != entrada.referencia && sobrescribir) {
        await _saf.delete(existente.uri);
      }
      await _saf.rename(entrada.referencia, nuevoNombre);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> copiar(
    EntradaArchivo entrada,
    RaizAutorizada destinoRaiz,
    String destinoRef, {
    bool sobrescribir = false,
  }) async {
    try {
      final existente = await _saf.child(destinoRef, <String>[entrada.nombre]);
      if (existente != null) {
        if (!sobrescribir) {
          throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre en el destino.');
        }
        await _saf.delete(existente.uri);
      }
      await _saf.copyTo(entrada.referencia, destinoRef);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> mover(
    EntradaArchivo entrada,
    RaizAutorizada destinoRaiz,
    String destinoRef, {
    bool sobrescribir = false,
  }) async {
    try {
      final existente = await _saf.child(destinoRef, <String>[entrada.nombre]);
      if (existente != null) {
        if (!sobrescribir) {
          throw const ErrorArchivo(TipoErrorArchivo.conflicto, 'Ya existe un elemento con ese nombre en el destino.');
        }
        await _saf.delete(existente.uri);
      }
      await _saf.moveTo(entrada.referencia, destinoRef);
    } on ErrorArchivo {
      rethrow;
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<void> eliminar(EntradaArchivo entrada) async {
    try {
      await _saf.delete(entrada.referencia);
    } catch (e) {
      throw ErrorArchivo.desde(e);
    }
  }

  @override
  Future<bool> existe(RaizAutorizada raiz, String referencia) async {
    try {
      return await _saf.exists(referencia);
    } catch (_) {
      return false;
    }
  }
}

/// Selecciona la implementación adecuada para una raíz.
class Servicios {
  Servicios({required this.privado, required this.ios, required this.saf});

  final ServicioArchivos privado;
  final ServicioArchivos ios;
  final ServicioArchivos saf;

  ServicioArchivos para(RaizAutorizada raiz) => switch (raiz.origen) {
        OrigenArchivo.privado => privado,
        OrigenArchivo.iosSeguro => ios,
        OrigenArchivo.saf => saf,
      };
}
