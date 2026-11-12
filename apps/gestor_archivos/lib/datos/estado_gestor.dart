import 'dart:convert';
import 'dart:io';

import 'package:comun/comun.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';
import 'package:selector_carpetas_ios/selector_carpetas_ios.dart';

import '../dominio/error_archivo.dart';
import '../dominio/modelos.dart';
import '../dominio/validador_rutas.dart';
import 'cache_miniaturas.dart';
import 'repositorio_ubicaciones.dart';
import 'servicio_archivos.dart';

enum ModoPortapapeles { copiar, mover }

class Portapapeles {
  const Portapapeles(this.entrada, this.modo);
  final EntradaArchivo entrada;
  final ModoPortapapeles modo;
}

/// Estado central del explorador: raíces, navegación, favoritos, recientes,
/// portapapeles y operaciones. La UI solo llama métodos y escucha cambios.
class EstadoGestor extends ChangeNotifier {
  EstadoGestor({
    required Servicios servicios,
    required RepositorioUbicaciones repositorio,
    required PreferenciasApp preferencias,
    required CacheMiniaturas cache,
    required Directory documentos,
    required Saf saf,
    SelectorCarpetasIos? selectorIos,
  })  : _servicios = servicios,
        _repo = repositorio,
        _prefs = preferencias,
        _cache = cache,
        _documentos = documentos,
        _saf = saf,
        _selectorIos = selectorIos ?? SelectorCarpetasIos();

  final Servicios _servicios;
  final RepositorioUbicaciones _repo;
  final PreferenciasApp _prefs;
  final CacheMiniaturas _cache;
  final Directory _documentos;
  final Saf _saf;
  final SelectorCarpetasIos _selectorIos;

  late RaizAutorizada raizPrivada;
  List<RaizAutorizada> raices = <RaizAutorizada>[];
  List<EntradaArchivo> entradas = <EntradaArchivo>[];
  List<EntradaArchivo> favoritos = <EntradaArchivo>[];
  List<EntradaArchivo> recientes = <EntradaArchivo>[];
  List<EntradaArchivo> pila = <EntradaArchivo>[];

  RaizAutorizada? raizActual;
  Portapapeles? portapapeles;
  bool cargando = false;
  bool inicializado = false;
  String? aviso;
  String orden = 'nombre';
  bool cuadricula = false;

  ServicioArchivos get _servicio =>
      raizActual == null ? _servicios.privado : _servicios.para(raizActual!);

  ServicioArchivos servicioDe(EntradaArchivo entrada) => _servicios.para(entrada.raiz);

  ServicioArchivos servicioDeRaiz(RaizAutorizada raiz) => _servicios.para(raiz);

  String get referenciaActual =>
      pila.isEmpty ? (raizActual?.referencia ?? raizPrivada.referencia) : pila.last.referencia;

  Future<void> iniciar() async {
    raizPrivada = RaizAutorizada(
      id: 'privado',
      nombre: T.espacioApp,
      origen: OrigenArchivo.privado,
      referencia: _documentos.path,
    );
    final guardadas = _repo.cargarRaices().where((r) => r.origen != OrigenArchivo.privado).toList();
    final externas = await _revalidarRaices(guardadas);
    raices = <RaizAutorizada>[raizPrivada, ...externas];
    favoritos = _repo.cargarFavoritos();
    recientes = _repo.cargarRecientes();
    await _revalidarEntradas(favoritos);
    await _revalidarEntradas(recientes);
    orden = _prefs.orden;
    cuadricula = _prefs.cuadricula;
    final ultima = _prefs.ultimaRaiz;
    final inicial = raices.firstWhere(
      (r) => r.id == ultima && r.disponible,
      orElse: () => raizPrivada,
    );
    await abrirRaiz(inicial, notificar: false);
    inicializado = true;
    notifyListeners();
  }

  Future<List<RaizAutorizada>> _revalidarRaices(List<RaizAutorizada> roots) async {
    final resultado = <RaizAutorizada>[];
    for (final root in roots) {
      var actual = root;
      try {
        if (root.origen == OrigenArchivo.saf) {
          final existe = await _servicios.saf.existe(root, root.referencia);
          actual = root.copyWith(disponible: existe);
        } else if (root.origen == OrigenArchivo.iosSeguro) {
          if (root.token == null) {
            actual = root.copyWith(disponible: false);
          } else {
            final resuelta = await _selectorIos.resolver(root.token!);
            if (resuelta == null) {
              actual = root.copyWith(disponible: false);
            } else {
              actual = root.copyWith(
                referencia: resuelta.ruta,
                nombre: resuelta.nombre.isEmpty ? root.nombre : resuelta.nombre,
                disponible: true,
              );
            }
          }
        }
      } catch (_) {
        actual = root.copyWith(disponible: false);
      }
      resultado.add(actual);
    }
    return resultado;
  }

  Future<void> _revalidarEntradas(List<EntradaArchivo> lista) async {
    for (var i = 0; i < lista.length; i++) {
      final entrada = lista[i];
      try {
        final servicio = _servicios.para(entrada.raiz);
        final existe = await servicio.existe(entrada.raiz, entrada.referencia);
        if (!existe) {
          lista[i] = entrada.copyWith(disponible: false);
        } else {
          final info = await servicio.info(entrada.raiz, entrada.referencia, nombre: entrada.nombre);
          if (info != null) lista[i] = info;
        }
      } catch (_) {
        lista[i] = entrada.copyWith(disponible: false);
      }
    }
  }

  Future<void> abrirRaiz(RaizAutorizada raiz, {bool notificar = true}) async {
    if (!raiz.disponible) {
      throw const ErrorArchivo(
        TipoErrorArchivo.sinPermiso,
        'La carpeta autorizada ya no está disponible. Vuelve a añadirla.',
      );
    }
    raizActual = raiz;
    pila = <EntradaArchivo>[];
    await _prefs.setUltimaRaiz(raiz.id);
    await _listar(raiz, raiz.referencia);
    if (notificar) notifyListeners();
  }

  Future<void> abrirCarpeta(EntradaArchivo entrada) async {
    if (!entrada.esCarpeta) return;
    final servicio = _servicios.para(entrada.raiz);
    final lista = await servicio.listar(entrada.raiz, entrada.referencia);
    raizActual = entrada.raiz;
    pila = <EntradaArchivo>[...pila, entrada];
    entradas = _ordenar(lista);
    aviso = null;
    notifyListeners();
  }

  Future<void> irA(int indice) async {
    if (indice < 0) {
      pila = <EntradaArchivo>[];
    } else {
      pila = pila.sublist(0, indice + 1);
    }
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  Future<void> subir() async {
    if (pila.isEmpty) return;
    pila = pila.sublist(0, pila.length - 1);
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  Future<void> recargar() async {
    if (raizActual == null) return;
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  Future<void> _listar(RaizAutorizada raiz, String referencia) async {
    cargando = true;
    aviso = null;
    notifyListeners();
    try {
      final lista = await _servicios.para(raiz).listar(raiz, referencia);
      entradas = _ordenar(lista);
    } on ErrorArchivo catch (e) {
      entradas = <EntradaArchivo>[];
      aviso = e.mensaje;
    } catch (e) {
      entradas = <EntradaArchivo>[];
      aviso = ErrorArchivo.desde(e).mensaje;
    } finally {
      cargando = false;
    }
  }

  List<EntradaArchivo> _ordenar(List<EntradaArchivo> lista) {
    final copia = List<EntradaArchivo>.from(lista);
    copia.sort((a, b) {
      if (a.esCarpeta != b.esCarpeta) return a.esCarpeta ? -1 : 1;
      switch (orden) {
        case 'fecha':
          final fa = a.modificado?.millisecondsSinceEpoch ?? 0;
          final fb = b.modificado?.millisecondsSinceEpoch ?? 0;
          return fb.compareTo(fa);
        case 'tamano':
          final ta = a.tamano ?? 0;
          final tb = b.tamano ?? 0;
          return tb.compareTo(ta);
        default:
          return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      }
    });
    return copia;
  }

  Future<void> cambiarOrden(String nuevo) async {
    orden = nuevo;
    await _prefs.setOrden(nuevo);
    entradas = _ordenar(entradas);
    notifyListeners();
  }

  Future<void> cambiarVista(bool valor) async {
    cuadricula = valor;
    await _prefs.setCuadricula(valor);
    notifyListeners();
  }

  Future<ArchivoAbierto> abrirArchivo(EntradaArchivo entrada) async {
    final tipo = MapaTipos.tipoDe(entrada.nombre);
    if (!tipo.tieneVisor) {
      throw ErrorArchivo(
        TipoErrorArchivo.noSoportado,
        'El formato ${tipo.descripcion} no tiene visor interno.',
      );
    }
    final servicio = _servicios.para(entrada.raiz);
    final max = tipo.esImagen ? 30 * 1024 * 1024 : 2 * 1024 * 1024;
    final bytes = await servicio.leer(entrada, maxBytes: max);
    String? texto;
    if (!tipo.esImagen) {
      texto = _decodificar(bytes);
    }
    await registrarReciente(entrada);
    return ArchivoAbierto(entrada: entrada, bytes: bytes, texto: texto);
  }

  String _decodificar(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    try {
      var texto = utf8.decode(bytes);
      if (texto.startsWith('﻿')) texto = texto.substring(1);
      return texto;
    } on FormatException {
      // Archivos antiguos en Latin-1: mostrar algo razonable en vez de fallar.
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  bool esFavorito(EntradaArchivo entrada) =>
      favoritos.any((f) => f.clave == entrada.clave);

  Future<void> alternarFavorito(EntradaArchivo entrada) async {
    if (esFavorito(entrada)) {
      favoritos.removeWhere((f) => f.clave == entrada.clave);
    } else {
      favoritos.insert(0, entrada);
    }
    await _repo.guardarFavoritos(favoritos);
    notifyListeners();
  }

  Future<void> registrarReciente(EntradaArchivo entrada) async {
    recientes.removeWhere((r) => r.clave == entrada.clave);
    recientes.insert(0, entrada);
    if (recientes.length > 30) recientes = recientes.sublist(0, 30);
    await _repo.guardarRecientes(recientes);
    notifyListeners();
  }

  Future<void> quitarFavorito(EntradaArchivo entrada) async {
    favoritos.removeWhere((f) => f.clave == entrada.clave);
    await _repo.guardarFavoritos(favoritos);
    notifyListeners();
  }

  Future<void> quitarReciente(EntradaArchivo entrada) async {
    recientes.removeWhere((r) => r.clave == entrada.clave);
    await _repo.guardarRecientes(recientes);
    notifyListeners();
  }

  Future<RaizAutorizada?> anadirCarpetaExterna() async {
    if (Platform.isAndroid) {
      final doc = await _saf.pickDirectory(persistablePermission: true);
      if (doc == null) return null;
      RaizAutorizada? existente;
      for (final r in raices) {
        if (r.referencia == doc.uri) existente = r;
      }
      if (existente != null) return existente;
      final raiz = RaizAutorizada(
        id: 'saf-${DateTime.now().microsecondsSinceEpoch}',
        nombre: doc.name,
        origen: OrigenArchivo.saf,
        referencia: doc.uri,
      );
      raices = <RaizAutorizada>[...raices, raiz];
    } else if (Platform.isIOS) {
      final carpeta = await _selectorIos.elegirCarpeta();
      if (carpeta == null) return null;
      final raiz = RaizAutorizada(
        id: 'ios-${DateTime.now().microsecondsSinceEpoch}',
        nombre: carpeta.nombre,
        origen: OrigenArchivo.iosSeguro,
        referencia: carpeta.ruta,
        token: carpeta.token,
      );
      raices = <RaizAutorizada>[...raices, raiz];
    } else {
      throw const ErrorArchivo(
        TipoErrorArchivo.noSoportado,
        'El selector de carpetas externas solo está disponible en Android e iOS.',
      );
    }
    await _repo.guardarRaices(raices.where((r) => r.origen != OrigenArchivo.privado).toList());
    notifyListeners();
    return raices.last;
  }

  Future<void> quitarRaiz(RaizAutorizada raiz) async {
    raices.removeWhere((r) => r.id == raiz.id);
    favoritos.removeWhere((f) => f.raiz.id == raiz.id);
    recientes.removeWhere((r) => r.raiz.id == raiz.id);
    await _repo.guardarRaices(raices.where((r) => r.origen != OrigenArchivo.privado).toList());
    await _repo.guardarFavoritos(favoritos);
    await _repo.guardarRecientes(recientes);
    try {
      if (raiz.origen == OrigenArchivo.saf) {
        await _saf.releasePersistedPermission(raiz.referencia);
      } else if (raiz.origen == OrigenArchivo.iosSeguro) {
        await _selectorIos.liberar();
      }
    } catch (_) {}
    if (raizActual?.id == raiz.id) {
      await abrirRaiz(raizPrivada, notificar: false);
    }
    notifyListeners();
  }

  Future<EntradaArchivo?> importarArchivo() async {
    final archivos = await FilePicker.pickFiles();
    if (archivos.isEmpty) return null;
    final archivo = archivos.first;
    final nombre = archivo.name;
    ValidadorRutas.exigirNombreValido(nombre);
    final bytes = await archivo.readAsBytes();
    if (bytes.isEmpty && (archivo.lengthSync() ?? 0) > 0) {
      throw const ErrorArchivo(TipoErrorArchivo.lectura, 'No se pudo leer el archivo elegido.');
    }
    final importados = Directory(p.join(_documentos.path, 'Importados'));
    await importados.create(recursive: true);
    final libre = _nombreLibre(importados.path, nombre);
    await _servicios.privado.escribir(
      raizPrivada,
      importados.path,
      libre,
      bytes,
    );
    final info = await _servicios.privado.info(raizPrivada, p.join(importados.path, libre), nombre: libre);
    aviso = 'Archivo importado en ${T.espacioApp}/Importados';
    notifyListeners();
    return info;
  }

  String _nombreLibre(String carpeta, String nombre) {
    final punto = nombre.lastIndexOf('.');
    final base = punto > 0 ? nombre.substring(0, punto) : nombre;
    final extension = punto > 0 ? nombre.substring(punto) : '';
    var candidato = nombre;
    var i = 1;
    while (File(p.join(carpeta, candidato)).existsSync() ||
        Directory(p.join(carpeta, candidato)).existsSync()) {
      candidato = '$base ($i)$extension';
      i++;
    }
    return candidato;
  }

  Future<void> crearCarpeta(String nombre) async {
    ValidadorRutas.exigirNombreValido(nombre);
    final servicio = _servicio;
    await servicio.crearCarpeta(raizActual!, referenciaActual, nombre);
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  Future<void> renombrar(EntradaArchivo entrada, String nuevoNombre, {bool sobrescribir = false}) async {
    ValidadorRutas.exigirNombreValido(nuevoNombre);
    final servicio = _servicios.para(entrada.raiz);
    await servicio.renombrar(entrada, referenciaActual, nuevoNombre, sobrescribir: sobrescribir);
    _quitarReferencias(entrada);
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  Future<void> eliminar(EntradaArchivo entrada) async {
    final servicio = _servicios.para(entrada.raiz);
    await servicio.eliminar(entrada);
    _quitarReferencias(entrada);
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  void _quitarReferencias(EntradaArchivo entrada) {
    favoritos.removeWhere((f) => f.clave == entrada.clave);
    recientes.removeWhere((r) => r.clave == entrada.clave);
    _repo.guardarFavoritos(favoritos);
    _repo.guardarRecientes(recientes);
  }

  void marcarPortapapeles(EntradaArchivo entrada, ModoPortapapeles modo) {
    portapapeles = Portapapeles(entrada, modo);
    notifyListeners();
  }

  void cancelarPortapapeles() {
    portapapeles = null;
    notifyListeners();
  }

  Future<void> pegar({bool sobrescribir = false}) async {
    final portado = portapapeles;
    if (portado == null) return;
    final destinoRaiz = raizActual!;
    final destinoRef = referenciaActual;
    final entrada = portado.entrada;
    final servicioOrigen = _servicios.para(entrada.raiz);
    final servicioDestino = _servicios.para(destinoRaiz);
    if (identical(servicioOrigen, servicioDestino)) {
      if (portado.modo == ModoPortapapeles.copiar) {
        await servicioOrigen.copiar(entrada, destinoRaiz, destinoRef, sobrescribir: sobrescribir);
      } else {
        await servicioOrigen.mover(entrada, destinoRaiz, destinoRef, sobrescribir: sobrescribir);
      }
    } else {
      await _transferirCruzado(entrada, destinoRaiz, destinoRef, mover: portado.modo == ModoPortapapeles.mover);
    }
    if (portado.modo == ModoPortapapeles.mover) portapapeles = null;
    _quitarReferencias(entrada);
    await _listar(raizActual!, referenciaActual);
    notifyListeners();
  }

  /// Copia recursiva entre proveedores distintos (SAF ↔ espacio privado/iOS).
  Future<void> _transferirCruzado(
    EntradaArchivo entrada,
    RaizAutorizada destinoRaiz,
    String destinoRef, {
    required bool mover,
  }) async {
    final origen = _servicios.para(entrada.raiz);
    final destino = _servicios.para(destinoRaiz);
    final existentes = await destino.listar(destinoRaiz, destinoRef);
    if (existentes.any((e) => e.nombre == entrada.nombre)) {
      throw const ErrorArchivo(
        TipoErrorArchivo.conflicto,
        'Ya existe un elemento con ese nombre en el destino.',
      );
    }
    if (entrada.esCarpeta) {
      await destino.crearCarpeta(destinoRaiz, destinoRef, entrada.nombre);
      final creada = (await destino.listar(destinoRaiz, destinoRef))
          .firstWhere((e) => e.nombre == entrada.nombre && e.esCarpeta);
      final hijos = await origen.listar(entrada.raiz, entrada.referencia);
      for (final hijo in hijos) {
        await _transferirCruzado(hijo, destinoRaiz, creada.referencia, mover: mover);
      }
    } else {
      final bytes = await origen.leer(entrada);
      await destino.escribir(destinoRaiz, destinoRef, entrada.nombre, bytes);
    }
    if (mover) {
      await origen.eliminar(entrada);
    }
  }

  Future<int> tamanoCache() => _cache.tamanoBytes();

  Future<void> limpiarCache() async {
    await _cache.limpiar();
    notifyListeners();
  }

  Future<Uint8List?> miniatura(EntradaArchivo entrada) async {
    if (!MapaTipos.tipoDe(entrada.nombre).esImagen) return null;
    final servicio = _servicios.para(entrada.raiz);
    return _cache.obtener(entrada, leer: () => servicio.leer(entrada, maxBytes: 20 * 1024 * 1024));
  }

  void limpiarAviso() {
    aviso = null;
    notifyListeners();
  }
}
