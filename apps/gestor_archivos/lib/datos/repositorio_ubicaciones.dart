import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';

/// Persistencia de raíces autorizadas, favoritos y recientes.
///
/// Se usa shared_preferences (SharedPreferences en Android y NSUserDefaults en
/// iOS) porque el volumen es pequeño y no requiere consultas relacionales.
class RepositorioUbicaciones {
  RepositorioUbicaciones(this._prefs);

  final SharedPreferences _prefs;

  static const _raices = 'p4_raices_v1';
  static const _favoritos = 'p4_favoritos_v1';
  static const _recientes = 'p4_recientes_v1';

  List<RaizAutorizada> cargarRaices() {
    final crudo = _prefs.getString(_raices);
    if (crudo == null) return <RaizAutorizada>[];
    try {
      final lista = jsonDecode(crudo) as List<dynamic>;
      return lista
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => RaizAutorizada.desdeJson(Map<String, Object?>.from(m)))
          .toList();
    } catch (_) {
      return <RaizAutorizada>[];
    }
  }

  Future<void> guardarRaices(List<RaizAutorizada> raices) async {
    await _prefs.setString(
      _raices,
      jsonEncode(raices.map((r) => r.aJson()).toList()),
    );
  }

  List<EntradaArchivo> cargarFavoritos() => _cargarEntradas(_favoritos);

  Future<void> guardarFavoritos(List<EntradaArchivo> favoritos) =>
      _guardarEntradas(_favoritos, favoritos.take(100).toList());

  List<EntradaArchivo> cargarRecientes() => _cargarEntradas(_recientes);

  Future<void> guardarRecientes(List<EntradaArchivo> recientes) =>
      _guardarEntradas(_recientes, recientes.take(30).toList());

  List<EntradaArchivo> _cargarEntradas(String clave) {
    final crudo = _prefs.getString(clave);
    if (crudo == null) return <EntradaArchivo>[];
    try {
      final lista = jsonDecode(crudo) as List<dynamic>;
      return lista
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => EntradaArchivo.desdeJson(Map<String, Object?>.from(m)))
          .toList();
    } catch (_) {
      return <EntradaArchivo>[];
    }
  }

  Future<void> _guardarEntradas(String clave, List<EntradaArchivo> entradas) async {
    await _prefs.setString(
      clave,
      jsonEncode(entradas.map((e) => e.aJson()).toList()),
    );
  }
}

/// Preferencias visuales y de navegación.
class PreferenciasApp {
  PreferenciasApp(this._prefs);

  final SharedPreferences _prefs;

  static const _temaVisual = 'p4_tema_visual';
  static const _modoTema = 'p4_modo_tema';
  static const _cuadricula = 'p4_cuadricula';
  static const _orden = 'p4_orden';
  static const _ultimaRaiz = 'p4_ultima_raiz';
  static const _semilla = 'p4_semilla_v1';

  String get temaVisual => _prefs.getString(_temaVisual) ?? 'guinda';
  Future<void> setTemaVisual(String valor) => _prefs.setString(_temaVisual, valor);

  String get modoTema => _prefs.getString(_modoTema) ?? 'sistema';
  Future<void> setModoTema(String valor) => _prefs.setString(_modoTema, valor);

  bool get cuadricula => _prefs.getBool(_cuadricula) ?? false;
  Future<void> setCuadricula(bool valor) => _prefs.setBool(_cuadricula, valor);

  String get orden => _prefs.getString(_orden) ?? 'nombre';
  Future<void> setOrden(String valor) => _prefs.setString(_orden, valor);

  String? get ultimaRaiz => _prefs.getString(_ultimaRaiz);
  Future<void> setUltimaRaiz(String? valor) async {
    if (valor == null) {
      await _prefs.remove(_ultimaRaiz);
    } else {
      await _prefs.setString(_ultimaRaiz, valor);
    }
  }

  bool get semillaCreada => _prefs.getBool(_semilla) ?? false;
  Future<void> marcarSemillaCreada() => _prefs.setBool(_semilla, true);
}
