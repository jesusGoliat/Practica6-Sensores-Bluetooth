import 'package:flutter/foundation.dart';
import 'package:sensores/sensores.dart';

import 'ajustes_sensores.dart';

/// Control por movimiento: la inclinación mueve un cursor y el giro voltea la
/// carta bajo el cursor. Solo escucha mientras está encendido, visible y la
/// app en primer plano.
class ControlMovimiento extends ChangeNotifier {
  ControlMovimiento({
    required this.ajustes,
    required this.alVoltear,
    this.filas = 4,
    this.columnas = 4,
  });

  final AjustesSensores ajustes;
  final void Function(int indice) alVoltear;
  int filas;
  int columnas;
  int cursor = 0;

  bool _encendido = false;
  bool _visible = true;
  bool _primerPlano = true;
  bool _liberado = false;
  ControladorSensor? _acel;
  ControladorSensor? _giro;
  LecturaSensor? _ultAcel;
  LecturaSensor? _ultGiro;
  final DetectorInclinacion _inclinacion = DetectorInclinacion();
  final DetectorGiro _detectorGiro = DetectorGiro();

  bool get encendido => _encendido;
  bool get escuchando => _encendido && _visible && _primerPlano;
  EstadoSensor? get estadoAcelerometro => _acel?.estado;
  EstadoSensor? get estadoGiroscopio => _giro?.estado;
  bool get ausente =>
      estadoAcelerometro == EstadoSensor.ausente || estadoGiroscopio == EstadoSensor.ausente;
  bool get simulado => ajustes.simulados;

  /// Número de suscripciones activas (para pruebas).
  int get suscripciones =>
      [_acel, _giro].where((c) => c != null && c.suscrito).length;

  void configurarTablero(int f, int c) {
    filas = f;
    columnas = c;
    if (cursor >= f * c) cursor = 0;
  }

  Future<void> alternar(bool valor) => valor ? encender() : Future.sync(apagar);

  Future<void> encender() async {
    if (_encendido || _liberado) return;
    _encendido = true;
    cursor = 0;
    _acel = ajustes.crearControlador(TipoSensor.acelerometro)..addListener(_alAcel);
    _giro = ajustes.crearControlador(TipoSensor.giroscopio)..addListener(_alGiro);
    notifyListeners();
    await _sincronizar();
  }

  void apagar() {
    if (!_encendido) return;
    _encendido = false;
    _liberarControladores();
    if (!_liberado) notifyListeners();
  }

  void _liberarControladores() {
    _acel?.removeListener(_alAcel);
    _giro?.removeListener(_alGiro);
    _acel?.dispose();
    _giro?.dispose();
    _acel = _giro = null;
    _ultAcel = _ultGiro = null;
  }

  set visible(bool v) {
    if (_visible == v) return;
    _visible = v;
    _sincronizar();
  }

  set primerPlano(bool v) {
    if (_primerPlano == v) return;
    _primerPlano = v;
    _sincronizar();
  }

  Future<void> _sincronizar() async {
    final cs = [_acel, _giro].whereType<ControladorSensor>().toList();
    if (!_encendido || cs.isEmpty) return;
    if (escuchando) {
      for (final c in cs) {
        if (c.estado == EstadoSensor.inactivo) {
          await c.iniciar();
        } else {
          c.reanudar();
        }
      }
    }
    if (!escuchando) {
      for (final c in cs) {
        c.pausar();
      }
    }
    if (!_liberado) notifyListeners();
  }

  void _alAcel() {
    final l = _acel?.ultima;
    if (l == null || identical(l, _ultAcel)) return;
    _ultAcel = l;
    if (!escuchando) return;
    final d = _inclinacion.procesar(l);
    if (d != Direccion.ninguna) mover(d);
  }

  void _alGiro() {
    final l = _giro?.ultima;
    if (l == null || identical(l, _ultGiro)) return;
    _ultGiro = l;
    if (!escuchando) return;
    if (_detectorGiro.procesar(l)) alVoltear(cursor);
  }

  void mover(Direccion d) {
    var f = cursor ~/ columnas, c = cursor % columnas;
    switch (d) {
      case Direccion.izquierda:
        c = (c - 1).clamp(0, columnas - 1);
      case Direccion.derecha:
        c = (c + 1).clamp(0, columnas - 1);
      case Direccion.arriba:
        f = (f - 1).clamp(0, filas - 1);
      case Direccion.abajo:
        f = (f + 1).clamp(0, filas - 1);
      case Direccion.ninguna:
        return;
    }
    final nuevo = f * columnas + c;
    if (nuevo != cursor) {
      cursor = nuevo;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _liberado = true;
    _encendido = false;
    _liberarControladores();
    super.dispose();
  }
}
