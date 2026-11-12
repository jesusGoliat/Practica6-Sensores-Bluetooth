import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/configuracion_partida.dart';
import '../dominio/estado_partida.dart';

/// Progreso acumulado del jugador.
class ProgresoJuego {
  ProgresoJuego({
    Map<String, int>? mejores,
    this.partidasJugadas = 0,
    Set<String>? nivelesCompletados,
  })  : mejores = mejores ?? <String, int>{},
        nivelesCompletados = nivelesCompletados ?? <String>{};

  final Map<String, int> mejores;
  int partidasJugadas;
  final Set<String> nivelesCompletados;

  int mejor(String nivel) => mejores[nivel] ?? 0;

  Map<String, Object?> aJson() => <String, Object?>{
        'mejores': mejores,
        'partidasJugadas': partidasJugadas,
        'nivelesCompletados': nivelesCompletados.toList(),
      };

  factory ProgresoJuego.desdeJson(Map<String, Object?> json) {
    final mejoresJson = json['mejores'];
    return ProgresoJuego(
      mejores: mejoresJson is Map
          ? <String, int>{
              for (final e in mejoresJson.entries)
                '${e.key}': (e.value as num?)?.toInt() ?? 0,
            }
          : <String, int>{},
      partidasJugadas: (json['partidasJugadas'] as num?)?.toInt() ?? 0,
      nivelesCompletados: (json['nivelesCompletados'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => '$e')
          .toSet(),
    );
  }
}

/// Preferencias persistentes del juego.
class PreferenciasJuego {
  PreferenciasJuego(this._prefs);

  final SharedPreferences _prefs;

  static const _tema = 'p4j_tema';
  static const _modoTema = 'p4j_modo_tema';
  static const _formato = 'p4j_formato';
  static const _sonido = 'p4j_sonido';
  static const _animaciones = 'p4j_animaciones';
  static const _nombre = 'p4j_nombre';
  static const _progreso = 'p4j_progreso';
  static const _nivel = 'p4j_nivel';
  static const _modo = 'p4j_modo';

  String get tema => _prefs.getString(_tema) ?? 'guinda';
  Future<void> setTema(String valor) => _prefs.setString(_tema, valor);

  String get modoTema => _prefs.getString(_modoTema) ?? 'sistema';
  Future<void> setModoTema(String valor) => _prefs.setString(_modoTema, valor);

  String get formato => _prefs.getString(_formato) ?? 'json';
  Future<void> setFormato(String valor) => _prefs.setString(_formato, valor);

  bool get sonido => _prefs.getBool(_sonido) ?? true;
  Future<void> setSonido(bool valor) => _prefs.setBool(_sonido, valor);

  bool get animaciones => _prefs.getBool(_animaciones) ?? true;
  Future<void> setAnimaciones(bool valor) => _prefs.setBool(_animaciones, valor);

  String get nombreJugador => _prefs.getString(_nombre) ?? 'Jugador IPN';
  Future<void> setNombreJugador(String valor) => _prefs.setString(_nombre, valor);

  String get ultimoNivel => _prefs.getString(_nivel) ?? 'campus';
  Future<void> setUltimoNivel(String valor) => _prefs.setString(_nivel, valor);

  String get ultimoModo => _prefs.getString(_modo) ?? 'relajado';
  Future<void> setUltimoModo(String valor) => _prefs.setString(_modo, valor);

  ConfiguracionPartida configuracion() => ConfiguracionPartida(
        nombreJugador: nombreJugador,
        sonido: sonido,
        animaciones: animaciones,
        formatoPreferido: formato,
        tema: tema,
      );

  ProgresoJuego get progreso {
    final crudo = _prefs.getString(_progreso);
    if (crudo == null) return ProgresoJuego();
    try {
      return ProgresoJuego.desdeJson(Map<String, Object?>.from(jsonDecode(crudo) as Map));
    } catch (_) {
      return ProgresoJuego();
    }
  }

  Future<void> guardarProgreso(ProgresoJuego progreso) =>
      _prefs.setString(_progreso, jsonEncode(progreso.aJson()));

  Future<ProgresoJuego> registrarResultado(EstadoPartida partida) async {
    final actual = progreso;
    actual.partidasJugadas++;
    if (partida.victoria) {
      actual.nivelesCompletados.add(partida.nivel);
      if (partida.puntaje > actual.mejor(partida.nivel)) {
        actual.mejores[partida.nivel] = partida.puntaje;
      }
    }
    await guardarProgreso(actual);
    return actual;
  }
}
