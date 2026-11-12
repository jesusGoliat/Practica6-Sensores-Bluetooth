/// Detección de mensajes ya procesados.
library;

import 'dart:collection';

/// Recuerda `(canal, sesion, seq)` ya procesados, con memoria acotada.
class ControlDuplicados {
  /// [porSesion] = secuencias recordadas por sesión; [maxSesiones] = sesiones.
  ControlDuplicados({this.porSesion = 256, this.maxSesiones = 64});

  /// Secuencias recordadas por sesión.
  final int porSesion;

  /// Máximo de sesiones recordadas (se descarta la menos reciente).
  final int maxSesiones;

  final LinkedHashMap<String, LinkedHashSet<int>> _vistos = LinkedHashMap();

  /// Devuelve `true` y lo registra si es la primera vez; `false` si repite.
  bool esNuevo(String canal, String sesion, int seq) {
    final clave = '$canal/$sesion';
    var conjunto = _vistos.remove(clave);
    conjunto ??= LinkedHashSet<int>();
    _vistos[clave] = conjunto; // mueve al final (más reciente)
    if (_vistos.length > maxSesiones) _vistos.remove(_vistos.keys.first);
    if (conjunto.contains(seq)) return false;
    conjunto.add(seq);
    if (conjunto.length > porSesion) conjunto.remove(conjunto.first);
    return true;
  }

  /// Olvida todo.
  void limpiar() => _vistos.clear();
}
