/// Configuraciones personalizadas que viajan dentro de cada partida.
class ConfiguracionPartida {
  const ConfiguracionPartida({
    this.nombreJugador = 'Jugador IPN',
    this.sonido = true,
    this.animaciones = true,
    this.formatoPreferido = 'json',
    this.tema = 'guinda',
  });

  final String nombreJugador;
  final bool sonido;
  final bool animaciones;
  final String formatoPreferido;
  final String tema;

  ConfiguracionPartida copyWith({
    String? nombreJugador,
    bool? sonido,
    bool? animaciones,
    String? formatoPreferido,
    String? tema,
  }) =>
      ConfiguracionPartida(
        nombreJugador: nombreJugador ?? this.nombreJugador,
        sonido: sonido ?? this.sonido,
        animaciones: animaciones ?? this.animaciones,
        formatoPreferido: formatoPreferido ?? this.formatoPreferido,
        tema: tema ?? this.tema,
      );

  Map<String, Object?> aJson() => <String, Object?>{
        'nombreJugador': nombreJugador,
        'sonido': sonido,
        'animaciones': animaciones,
        'formatoPreferido': formatoPreferido,
        'tema': tema,
      };

  factory ConfiguracionPartida.desdeJson(Map<String, Object?> json) => ConfiguracionPartida(
        nombreJugador: json['nombreJugador'] as String? ?? 'Jugador IPN',
        sonido: json['sonido'] as bool? ?? true,
        animaciones: json['animaciones'] as bool? ?? true,
        formatoPreferido: json['formatoPreferido'] as String? ?? 'json',
        tema: json['tema'] as String? ?? 'guinda',
      );
}
