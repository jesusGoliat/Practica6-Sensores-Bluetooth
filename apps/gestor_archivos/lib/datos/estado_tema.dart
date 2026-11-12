import 'package:comun/comun.dart';
import 'package:flutter/material.dart';

import '../datos/repositorio_ubicaciones.dart';

/// Estado del tema Guinda/Azul y del modo claro/oscuro.
class EstadoTema extends ChangeNotifier {
  EstadoTema(this._prefs) {
    _visual = _prefs.temaVisual == 'azul' ? TemaVisual.azul : TemaVisual.guinda;
    _modo = switch (_prefs.modoTema) {
      'claro' => ThemeMode.light,
      'oscuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  final PreferenciasApp _prefs;
  late TemaVisual _visual;
  late ThemeMode _modo;

  TemaVisual get visual => _visual;
  ThemeMode get modo => _modo;
  String get nombreVisual => PaletaApp.nombre(_visual);

  ThemeData get temaClaro => construirTema(visual: _visual, brillo: Brightness.light);
  ThemeData get temaOscuro => construirTema(visual: _visual, brillo: Brightness.dark);

  Future<void> cambiarVisual(TemaVisual visual) async {
    if (visual == _visual) return;
    _visual = visual;
    await _prefs.setTemaVisual(visual.name);
    notifyListeners();
  }

  Future<void> cambiarModo(ThemeMode modo) async {
    if (modo == _modo) return;
    _modo = modo;
    await _prefs.setModoTema(switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'oscuro',
      ThemeMode.system => 'sistema',
    });
    notifyListeners();
  }
}
