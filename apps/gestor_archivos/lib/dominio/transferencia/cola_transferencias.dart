/// Cola FIFO acotada de envíos pendientes (máx. 5).
class ColaTransferencias<T> {
  ColaTransferencias({this.maxPendientes = maxPendientesPredeterminado});

  static const String mensajeLlena =
      'La cola está llena (máximo 5 pendientes). Espera a que termine alguno.';

  static const int maxPendientesPredeterminado = 5;

  final int maxPendientes;
  final List<T> _items = <T>[];

  int get longitud => _items.length;
  bool get llena => _items.length >= maxPendientes;
  bool get vacia => _items.isEmpty;
  List<T> get items => List<T>.unmodifiable(_items);

  /// Devuelve `null` si se encoló, o el mensaje de rechazo si está llena.
  String? encolar(T item) {
    if (llena) return mensajeLlena;
    _items.add(item);
    return null;
  }

  T? siguiente() => _items.isEmpty ? null : _items.removeAt(0);

  bool quitar(bool Function(T) donde) {
    final i = _items.indexWhere(donde);
    if (i < 0) return false;
    _items.removeAt(i);
    return true;
  }

  void vaciar() => _items.clear();
}
