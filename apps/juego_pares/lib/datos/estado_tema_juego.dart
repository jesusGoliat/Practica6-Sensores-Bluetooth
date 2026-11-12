import 'package:comun/comun.dart';
import 'package:flutter/material.dart';

import 'preferencias_juego.dart';

class EstadoTemaJuego extends ChangeNotifier {
  EstadoTemaJuego(this._prefs) {
    _visual = _prefs.tema == 'azul' ? TemaVisual.azul : TemaVisual.guinda;
    _modo = switch (_prefs.modoTema) {
      'claro' => ThemeMode.light,
      'oscuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  final PreferenciasJuego _prefs;
  late TemaVisual _visual;
  late ThemeMode _modo;

  TemaVisual get visual => _visual;
  ThemeMode get modo => _modo;
  String get nombreVisual => PaletaApp.nombre(_visual);
  ThemeData get temaClaro => construirTema(visual: _visual, brillo: Brightness.light);
  ThemeData get temaOscuro => construirTema(visual: _visual, brillo: Brightness.dark);

  Future<void> cambiarVisual(TemaVisual visual) async {
    if (_visual == visual) return;
    _visual = visual;
    await _prefs.setTema(visual.name);
    notifyListeners();
  }

  Future<void> cambiarModo(ThemeMode modo) async {
    if (_modo == modo) return;
    _modo = modo;
    await _prefs.setModoTema(switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'oscuro',
      ThemeMode.system => 'sistema',
    });
    notifyListeners();
  }
}
