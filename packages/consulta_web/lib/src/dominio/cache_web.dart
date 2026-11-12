/// Caché LRU de respuestas web con persistencia JSON.
library;

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'almacen.dart';

/// Una respuesta guardada.
class EntradaCache {
  /// Crea una entrada (texto o bytes).
  EntradaCache({
    required this.url,
    required this.tipo,
    required this.estado,
    required this.fecha,
    this.texto,
    this.bytes,
    this.urlFinal,
    this.ms,
  });

  /// URL pedida (clave).
  final String url;

  /// Tipo de contenido.
  final String tipo;

  /// Código HTTP.
  final int estado;

  /// Fecha de la respuesta original.
  final DateTime fecha;

  /// Cuerpo de texto (o `null` si es imagen).
  final String? texto;

  /// Cuerpo binario (imágenes).
  final Uint8List? bytes;

  /// URL final tras redirecciones.
  final String? urlFinal;

  /// Tiempo original en ms.
  final int? ms;

  /// Tamaño aproximado en bytes.
  int get tamano => bytes?.length ?? utf8.encode(texto ?? '').length;

  Map<String, dynamic> toJson() => {
        'url': url,
        'tipo': tipo,
        'estado': estado,
        'fecha': fecha.toUtc().toIso8601String(),
        if (texto != null) 'texto': texto,
        if (bytes != null) 'b64': base64Encode(bytes!),
        if (urlFinal != null) 'urlFinal': urlFinal,
        if (ms != null) 'ms': ms,
      };

  /// Decodifica; devuelve `null` si el mapa es inválido.
  static EntradaCache? desdeJson(Object? j) {
    if (j is! Map) return null;
    try {
      return EntradaCache(
        url: j['url'] as String,
        tipo: j['tipo'] as String,
        estado: j['estado'] as int,
        fecha: DateTime.parse(j['fecha'] as String),
        texto: j['texto'] as String?,
        bytes: j['b64'] == null ? null : base64Decode(j['b64'] as String),
        urlFinal: j['urlFinal'] as String?,
        ms: j['ms'] as int?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Caché de máximo [capacidad] entradas con expulsión LRU.
class CacheWeb extends ChangeNotifier {
  /// Crea la caché; [almacen] opcional para persistir.
  CacheWeb({this.almacen, this.capacidad = 30});

  /// Persistencia.
  final AlmacenTexto? almacen;

  /// Máximo de entradas.
  final int capacidad;

  /// Clave de persistencia.
  static const String clave = 'cache';

  final LinkedHashMap<String, EntradaCache> _mapa = LinkedHashMap();

  /// Entradas de la más reciente a la más antigua.
  List<EntradaCache> get entradas => _mapa.values.toList().reversed.toList();

  /// Cantidad de entradas.
  int get longitud => _mapa.length;

  /// Carga desde el almacén (ignora datos corruptos).
  Future<void> cargar() async {
    final s = await almacen?.leer(clave);
    if (s == null) return;
    try {
      final lista = jsonDecode(s);
      if (lista is! List) return;
      _mapa.clear();
      for (final j in lista) {
        final e = EntradaCache.desdeJson(j);
        if (e != null) _mapa[e.url] = e;
      }
      while (_mapa.length > capacidad) {
        _mapa.remove(_mapa.keys.first);
      }
      notifyListeners();
    } catch (_) {
      // Archivo corrupto: se empieza vacío.
    }
  }

  /// Entrada de [url] marcándola como usada recientemente.
  EntradaCache? obtener(String url) {
    final e = _mapa.remove(url);
    if (e != null) _mapa[url] = e;
    return e;
  }

  /// Consulta sin alterar el orden LRU.
  EntradaCache? mirar(String url) => _mapa[url];

  /// Guarda o reemplaza una entrada.
  Future<void> guardar(EntradaCache e) async {
    _mapa.remove(e.url);
    _mapa[e.url] = e;
    while (_mapa.length > capacidad) {
      _mapa.remove(_mapa.keys.first);
    }
    notifyListeners();
    await _persistir();
  }

  /// Elimina una entrada.
  Future<void> eliminar(String url) async {
    if (_mapa.remove(url) != null) {
      notifyListeners();
      await _persistir();
    }
  }

  /// Vacía la caché.
  Future<void> vaciar() async {
    _mapa.clear();
    notifyListeners();
    await _persistir();
  }

  Future<void> _persistir() async {
    await almacen?.escribir(
        clave, jsonEncode([for (final e in _mapa.values) e.toJson()]));
  }
}
