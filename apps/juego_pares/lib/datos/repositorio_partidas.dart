import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../dominio/error_partida.dart';
import '../dominio/estado_partida.dart';
import 'codificadores.dart';

/// Una partida encontrada en el almacenamiento privado. `estado` es null y
/// `error` explica el problema cuando el archivo está dañado.
class PartidaGuardada {
  const PartidaGuardada({
    required this.archivo,
    required this.formato,
    required this.modificada,
    required this.tamano,
    this.estado,
    this.error,
  });

  final File archivo;
  final String formato;
  final DateTime modificada;
  final int tamano;
  final EstadoPartida? estado;
  final String? error;

  String get nombre => p.basename(archivo.path);
  String get nombreVisible =>
      estado?.etiqueta.isNotEmpty == true ? estado!.etiqueta : p.basenameWithoutExtension(archivo.path);
  bool get valida => estado != null;
}

/// Guarda y carga partidas en el almacenamiento privado de la app.
/// El formato se elige por extensión y la escritura es atómica.
class RepositorioPartidas {
  RepositorioPartidas(Directory base) : _base = base;

  final Directory _base;
  static const String nombreAutoguardado = 'autoguardado.json';

  Future<void> asegurar() => _base.create(recursive: true);

  Future<List<PartidaGuardada>> listar() async {
    await asegurar();
    final resultado = <PartidaGuardada>[];
    await for (final entidad in _base.list()) {
      if (entidad is! File) continue;
      final nombre = p.basename(entidad.path);
      if (nombre == nombreAutoguardado) continue;
      final extension = p.extension(nombre).replaceFirst('.', '').toLowerCase();
      if (extension != 'json' && extension != 'xml' && extension != 'txt') continue;
      final stat = await entidad.stat();
      try {
        final contenido = await entidad.readAsString();
        final codificador = codificadorPorExtension(extension);
        final estado = codificador.decodificar(contenido);
        resultado.add(PartidaGuardada(
          archivo: entidad,
          formato: codificador.etiqueta,
          modificada: stat.modified,
          tamano: stat.size,
          estado: estado,
        ));
      } on ErrorPartida catch (e) {
        resultado.add(PartidaGuardada(
          archivo: entidad,
          formato: extension.toUpperCase(),
          modificada: stat.modified,
          tamano: stat.size,
          error: e.mensaje,
        ));
      } catch (e) {
        resultado.add(PartidaGuardada(
          archivo: entidad,
          formato: extension.toUpperCase(),
          modificada: stat.modified,
          tamano: stat.size,
          error: 'No se pudo leer la partida: $e',
        ));
      }
    }
    resultado.sort((a, b) => b.modificada.compareTo(a.modificada));
    return resultado;
  }

  Future<PartidaGuardada> guardar(
    EstadoPartida partida, {
    required String formato,
    String? nombre,
    bool autoguardado = false,
  }) async {
    await asegurar();
    final codificador = codificadorPorExtension(formato);
    final contenido = codificador.codificar(partida);
    final limpio = _limpiarNombre(nombre ?? 'partida_${_marca(partida)}');
    final archivo = autoguardado
        ? File(p.join(_base.path, nombreAutoguardado))
        : File(p.join(_base.path, '$limpio.${codificador.extension}'));
    await _escribirAtomico(archivo, contenido);
    final stat = await archivo.stat();
    return PartidaGuardada(
      archivo: archivo,
      formato: codificador.etiqueta,
      modificada: stat.modified,
      tamano: stat.size,
      estado: partida,
    );
  }

  Future<EstadoPartida> cargar(PartidaGuardada guardada) async {
    if (!await guardada.archivo.exists()) {
      throw const ErrorPartida(TipoErrorPartida.incompleta, 'La partida ya no existe.');
    }
    final contenido = await guardada.archivo.readAsString();
    final codificador = codificadorPorExtension(
      p.extension(guardada.archivo.path).replaceFirst('.', ''),
    );
    return codificador.decodificar(contenido);
  }

  Future<void> eliminar(PartidaGuardada guardada) async {
    if (await guardada.archivo.exists()) {
      await guardada.archivo.delete();
    }
  }

  Future<PartidaGuardada> actualizarEtiqueta(PartidaGuardada guardada, String etiqueta) async {
    final estado = await cargar(guardada);
    final actualizado = estado.copyWith(etiqueta: etiqueta, actualizada: DateTime.now());
    final formato = p.extension(guardada.archivo.path).replaceFirst('.', '');
    final codificador = codificadorPorExtension(formato);
    await _escribirAtomico(guardada.archivo, codificador.codificar(actualizado));
    final stat = await guardada.archivo.stat();
    return PartidaGuardada(
      archivo: guardada.archivo,
      formato: codificador.etiqueta,
      modificada: stat.modified,
      tamano: stat.size,
      estado: actualizado,
    );
  }

  Future<String> contenidoCrudo(PartidaGuardada guardada) => guardada.archivo.readAsString();

  Future<List<int>> bytesParaExportar(EstadoPartida partida, String formato) async {
    final codificador = codificadorPorExtension(formato);
    return utf8.encode(codificador.codificar(partida));
  }

  Future<void> guardarAutoguardado(EstadoPartida partida) async {
    await guardar(partida, formato: 'json', autoguardado: true);
  }

  Future<EstadoPartida?> cargarAutoguardado() async {
    final archivo = File(p.join(_base.path, nombreAutoguardado));
    if (!await archivo.exists()) return null;
    try {
      final contenido = await archivo.readAsString();
      final estado = const CodificadorJson().decodificar(contenido);
      if (estado.terminada) {
        await archivo.delete();
        return null;
      }
      return estado;
    } catch (_) {
      // Un autoguardado dañado no debe impedir abrir la app.
      await archivo.delete();
      return null;
    }
  }

  Future<void> borrarAutoguardado() async {
    final archivo = File(p.join(_base.path, nombreAutoguardado));
    if (await archivo.exists()) await archivo.delete();
  }

  Future<PartidaGuardada> importar(File origen, String nombre) async {
    await asegurar();
    final extension = p.extension(nombre).replaceFirst('.', '').toLowerCase();
    final codificador = codificadorPorExtension(extension);
    final contenido = await origen.readAsString();
    final estado = codificador.decodificar(contenido);
    final limpio = _limpiarNombre(p.basenameWithoutExtension(nombre));
    final destino = File(p.join(_base.path, '$limpio.${codificador.extension}'));
    await _escribirAtomico(destino, codificador.codificar(estado));
    final stat = await destino.stat();
    return PartidaGuardada(
      archivo: destino,
      formato: codificador.etiqueta,
      modificada: stat.modified,
      tamano: stat.size,
      estado: estado,
    );
  }

  String _marca(EstadoPartida partida) {
    final f = partida.creada;
    return '${f.year}${f.month.toString().padLeft(2, '0')}${f.day.toString().padLeft(2, '0')}'
        '_${f.hour.toString().padLeft(2, '0')}${f.minute.toString().padLeft(2, '0')}'
        '_${partida.semilla}';
  }

  String _limpiarNombre(String nombre) {
    final limpio = nombre
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return limpio.isEmpty ? 'partida' : limpio;
  }

  Future<void> _escribirAtomico(File destino, String contenido) async {
    final temporal = File('${destino.path}.tmp');
    await temporal.writeAsString(contenido, flush: true);
    try {
      await temporal.rename(destino.path);
    } on FileSystemException {
      // Algunos sistemas no permiten renombrar sobre un archivo existente.
      if (await destino.exists()) await destino.delete();
      await temporal.rename(destino.path);
    }
  }
}
