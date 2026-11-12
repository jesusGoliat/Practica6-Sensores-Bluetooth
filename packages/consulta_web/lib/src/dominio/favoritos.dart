/// Favoritos persistentes.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'almacen.dart';

/// Lista de URL favoritas.
class Favoritos extends ChangeNotifier {
  /// Crea la lista; [almacen] opcional.
  Favoritos({this.almacen});

  /// Persistencia.
  final AlmacenTexto? almacen;

  /// Clave de persistencia.
  static const String clave = 'favoritos';

  final List<String> _urls = [];

  /// URLs favoritas.
  List<String> get urls => List.unmodifiable(_urls);

  /// `true` si [url] es favorita.
  bool contiene(String url) => _urls.contains(url);

  /// Carga desde el almacén.
  Future<void> cargar() async {
    final s = await almacen?.leer(clave);
    if (s == null) return;
    try {
      final l = jsonDecode(s);
      if (l is List) {
        _urls
          ..clear()
          ..addAll(l.whereType<String>());
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Agrega o quita [url].
  Future<void> alternar(String url) async {
    if (!_urls.remove(url)) _urls.add(url);
    notifyListeners();
    await almacen?.escribir(clave, jsonEncode(_urls));
  }
}
