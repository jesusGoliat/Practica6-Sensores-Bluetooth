/// Límite de peticiones por ventana deslizante.
library;

/// Máximo [maximo] peticiones en [ventana] (10 por minuto por defecto).
class LimitadorPeticiones {
  /// Crea el limitador con reloj inyectable.
  LimitadorPeticiones({
    this.maximo = 10,
    this.ventana = const Duration(minutes: 1),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  /// Peticiones permitidas por ventana.
  final int maximo;

  /// Duración de la ventana.
  final Duration ventana;
  final DateTime Function() _reloj;
  final List<DateTime> _marcas = [];

  /// Registra una petición. Devuelve `false` (sin registrar) si excede el límite.
  bool intentar() {
    final ahora = _reloj();
    _marcas.removeWhere((m) => ahora.difference(m) >= ventana);
    if (_marcas.length >= maximo) return false;
    _marcas.add(ahora);
    return true;
  }

  /// Olvida el historial (sesión nueva).
  void reiniciar() => _marcas.clear();
}
