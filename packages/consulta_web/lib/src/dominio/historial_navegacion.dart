/// Historial local con semántica de navegador.
library;

import 'package:flutter/foundation.dart';

/// Pila atrás/adelante: visitar una URL nueva descarta el "adelante".
class HistorialNavegacion extends ChangeNotifier {
  final List<String> _urls = [];
  int _indice = -1;

  /// URL actual o `null`.
  String? get actual => _indice < 0 ? null : _urls[_indice];

  /// Hay una página anterior.
  bool get puedeAtras => _indice > 0;

  /// Hay una página siguiente.
  bool get puedeAdelante => _indice >= 0 && _indice < _urls.length - 1;

  /// Copia de las URLs visitadas.
  List<String> get urls => List.unmodifiable(_urls);

  /// Registra una visita (ignora repetir la actual).
  void visitar(String url) {
    if (url == actual) return;
    if (_indice < _urls.length - 1) _urls.removeRange(_indice + 1, _urls.length);
    _urls.add(url);
    _indice = _urls.length - 1;
    notifyListeners();
  }

  /// Retrocede y devuelve la URL, o `null`.
  String? atras() {
    if (!puedeAtras) return null;
    _indice--;
    notifyListeners();
    return actual;
  }

  /// Avanza y devuelve la URL, o `null`.
  String? adelante() {
    if (!puedeAdelante) return null;
    _indice++;
    notifyListeners();
    return actual;
  }
}
