import 'package:audioplayers/audioplayers.dart';

/// Efectos de sonido generados localmente. Si el dispositivo o el simulador
/// no pueden reproducirlos, la app sigue funcionando.
class SonidoService {
  SonidoService({this.habilitado = true});

  AudioPlayer? _player;
  bool habilitado;

  /// Crear el reproductor es perezoso: en pruebas sin plugin de audio no se
  /// inicializa y la app no falla.
  AudioPlayer? get _reproductor {
    if (!habilitado) return null;
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (_) {
      return null;
    }
  }

  Future<void> reproducir(String archivo) async {
    final player = _reproductor;
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource('audio/$archivo.wav'), mode: PlayerMode.lowLatency);
    } catch (_) {
      // Sin audio disponible: no se bloquea la partida.
    }
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
