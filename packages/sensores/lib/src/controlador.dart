import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fuentes.dart';
import 'modelo.dart';

/// Controla la suscripción a un [FuenteSensor]. Nunca lanza hacia la UI.
class ControladorSensor extends ChangeNotifier {
  ControladorSensor(
    this.fuente, {
    this.periodo = const Duration(milliseconds: 100),
    this.limiteSinDatos = const Duration(seconds: 2),
  });

  static const int maxBitacora = 50;

  final FuenteSensor fuente;
  final Duration periodo;
  final Duration limiteSinDatos;

  EstadoSensor _estado = EstadoSensor.inactivo;
  LecturaSensor? _ultima;
  final List<EventoBitacora> _bitacora = [];
  StreamSubscription<LecturaSensor>? _sub;
  Timer? _temporizador;
  bool _liberado = false;
  bool _invalidaAvisada = false;
  int _generacion = 0;

  EstadoSensor get estado => _estado;
  LecturaSensor? get ultima => _ultima;
  List<EventoBitacora> get bitacora => List.unmodifiable(_bitacora);

  /// Verdadero si hay una suscripción activa.
  bool get suscrito => _sub != null;

  void _registrar(String descripcion) {
    _bitacora.add(EventoBitacora(DateTime.now(), descripcion));
    if (_bitacora.length > maxBitacora) {
      _bitacora.removeRange(0, _bitacora.length - maxBitacora);
    }
  }

  void _cambiar(EstadoSensor nuevo, [String? evento]) {
    _estado = nuevo;
    if (evento != null) _registrar(evento);
    if (!_liberado) notifyListeners();
  }

  void _cancelar() {
    _generacion++;
    _temporizador?.cancel();
    _temporizador = null;
    final s = _sub;
    _sub = null;
    if (s != null) {
      unawaited(s.cancel().catchError((Object _) {}));
    }
  }

  void _armarTemporizador() {
    _temporizador?.cancel();
    _temporizador = Timer(limiteSinDatos, () {
      if (_sub != null && _estado == EstadoSensor.escuchando) {
        _cambiar(EstadoSensor.sinDatos, 'Sin datos durante ${limiteSinDatos.inMilliseconds} ms');
      }
    });
  }

  void _suscribir() {
    _cancelar();
    final gen = _generacion;
    try {
      _sub = fuente.lecturas(periodo).listen(
        (l) => _alLeer(l, gen),
        onError: (Object e) {
          if (gen != _generacion) return;
          _cancelar();
          _cambiar(EstadoSensor.error, 'Error: $e');
        },
        cancelOnError: false,
      );
      _armarTemporizador();
    } catch (e) {
      _cancelar();
      _cambiar(EstadoSensor.error, 'Error: $e');
    }
  }

  void _alLeer(LecturaSensor l, int gen) {
    if (gen != _generacion || _liberado) return;
    if (!l.esValida) {
      if (!_invalidaAvisada) {
        _invalidaAvisada = true;
        _registrar('Error: lectura no válida ignorada');
        notifyListeners();
      }
      return;
    }
    _invalidaAvisada = false;
    _ultima = l;
    _armarTemporizador();
    if (_estado != EstadoSensor.escuchando) {
      _cambiar(EstadoSensor.escuchando,
          _estado == EstadoSensor.sinDatos ? 'Datos recuperados' : null);
    } else {
      notifyListeners();
    }
  }

  /// Comprueba disponibilidad y empieza a escuchar.
  Future<void> iniciar() async {
    if (_liberado) return;
    if (_estado == EstadoSensor.escuchando || _estado == EstadoSensor.sinDatos) return;
    bool ok;
    try {
      ok = await fuente.disponible();
    } catch (_) {
      ok = false;
    }
    if (_liberado) return;
    if (!ok) {
      _cancelar();
      _cambiar(EstadoSensor.ausente, 'Sensor ausente');
      return;
    }
    _suscribir();
    _cambiar(EstadoSensor.escuchando, 'Inicio');
  }

  /// Detiene y cancela la suscripción.
  void detener() {
    if (_liberado || _estado == EstadoSensor.inactivo) return;
    _cancelar();
    _cambiar(EstadoSensor.inactivo, 'Detenido');
  }

  /// Cancela la suscripción sin perder la última lectura.
  void pausar() {
    if (_liberado) return;
    if (_estado != EstadoSensor.escuchando && _estado != EstadoSensor.sinDatos) return;
    _cancelar();
    _cambiar(EstadoSensor.pausado, 'Pausa');
  }

  /// Vuelve a suscribirse si estaba en pausa.
  void reanudar() {
    if (_liberado || _estado != EstadoSensor.pausado) return;
    _suscribir();
    _cambiar(EstadoSensor.escuchando, 'Reanuda');
  }

  @override
  void dispose() {
    _liberado = true;
    _cancelar();
    super.dispose();
  }
}
