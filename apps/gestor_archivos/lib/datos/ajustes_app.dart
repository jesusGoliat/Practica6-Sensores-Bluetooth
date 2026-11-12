import 'package:flutter/foundation.dart';

import 'repositorio_ubicaciones.dart';

/// Ajustes de la Práctica 6: sacudir, sensores simulados y diagnóstico.
class AjustesApp extends ChangeNotifier {
  AjustesApp([this._prefs])
      : _sacudir = _prefs?.sacudirActualiza ?? true,
        _simulados = _prefs?.sensoresSimulados ?? false;

  final PreferenciasApp? _prefs;
  bool _sacudir;
  bool _simulados;
  bool _alterarBloque = false;
  bool _alterarNombre = false;

  bool get sacudirActualiza => _sacudir;
  bool get sensoresSimulados => _simulados;

  /// Solo en memoria: no queda activo tras reiniciar.
  bool get alterarBloque => _alterarBloque;
  bool get alterarNombre => _alterarNombre;

  Future<void> setSacudir(bool v) async {
    _sacudir = v;
    notifyListeners();
    await _prefs?.setSacudirActualiza(v);
  }

  Future<void> setSimulados(bool v) async {
    _simulados = v;
    notifyListeners();
    await _prefs?.setSensoresSimulados(v);
  }

  void setAlterarBloque(bool v) {
    _alterarBloque = v;
    notifyListeners();
  }

  void setAlterarNombre(bool v) {
    _alterarNombre = v;
    notifyListeners();
  }
}
