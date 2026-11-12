import 'dart:math';

import 'package:enlace_ble/enlace_ble.dart' show Sobre;

import 'carta.dart';
import 'configuracion_partida.dart';
import 'motor_juego.dart';

/// Rol (y jugador) de una partida en red para dos participantes.
enum RolRed {
  anfitrion,
  invitado;

  RolRed get rival => this == anfitrion ? invitado : anfitrion;

  static RolRed? desdeNombre(Object? nombre) {
    for (final r in values) {
      if (r.name == nombre) return r;
    }
    return null;
  }
}

/// Un jugador es lo mismo que un rol.
typedef JugadorRed = RolRed;

/// Estados de la sesión de red.
enum EstadoSesionRed {
  esperando,
  conectando,
  enJuego,
  pausadaPorDesconexion,
  terminada,
  abandonada;

  static EstadoSesionRed desdeNombre(Object? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => EstadoSesionRed.pausadaPorDesconexion);
}

enum TipoResultadoJugada { aplicada, duplicada, rechazada }

/// Resultado de validar o aplicar una jugada.
class ResultadoJugadaRed {
  const ResultadoJugadaRed._(
    this.tipo, {
    this.motivo,
    this.codigo,
    this.esPrimera = false,
    this.acierto = false,
    this.terminada = false,
  });

  /// Jugada ya procesada antes (mismo seq): se ignora.
  static const ResultadoJugadaRed duplicada =
      ResultadoJugadaRed._(TipoResultadoJugada.duplicada);

  const ResultadoJugadaRed.aplicada({
    bool esPrimera = false,
    bool acierto = false,
    bool terminada = false,
  }) : this._(TipoResultadoJugada.aplicada,
            esPrimera: esPrimera, acierto: acierto, terminada: terminada);

  /// [codigo] es el de `ERROR` del protocolo: `turno`, `jugada` o `sesion`.
  const ResultadoJugadaRed.rechazada(String motivo, {String codigo = 'jugada'})
      : this._(TipoResultadoJugada.rechazada, motivo: motivo, codigo: codigo);

  final TipoResultadoJugada tipo;
  final String? motivo;
  final String? codigo;
  final bool esPrimera;
  final bool acierto;
  final bool terminada;

  bool get aceptada => tipo == TipoResultadoJugada.aplicada;
  bool get esDuplicada => tipo == TipoResultadoJugada.duplicada;
  bool get esRechazada => tipo == TipoResultadoJugada.rechazada;
}

/// Qué debe hacer el anfitrión ante un `REANUDAR`.
enum ResultadoReanudar { sesionDesconocida, partidaTerminada, enviarEstado }

/// Jugada ya aplicada (se guarda para reconstruir el tablero).
class JugadaRed {
  const JugadaRed(this.jugador, this.indice, this.seq);
  final RolRed jugador;
  final int indice;
  final int seq;

  Map<String, Object?> aJson() => {'j': jugador.name, 'i': indice, 's': seq};
}

/// Normaliza el nivel recibido (`campus`/`4x4`, `laboratorio`/`6x6`).
String? normalizarNivelRed(Object? nivel) => switch (nivel) {
      'campus' || '4x4' => 'campus',
      'laboratorio' || '6x6' => 'laboratorio',
      _ => null,
    };

/// Máquina de estados pura de una partida de pares para dos jugadores.
///
/// Ambos extremos construyen el mismo tablero con la misma semilla. Se
/// conserva el turno con un acierto y se pasa con un fallo. La instantánea del
/// anfitrión es la fuente de verdad.
class SesionPartidaRed {
  SesionPartidaRed._({
    required this.idPartida,
    required this.semilla,
    required this.nivel,
    required this.anfitrionEmpieza,
    required this.rol,
    required this.reloj,
    EstadoSesionRed estado = EstadoSesionRed.esperando,
  })  : estado = estado,
        tablero = _construirTablero(nivel, semilla),
        turno = anfitrionEmpieza ? RolRed.anfitrion : RolRed.invitado,
        actualizada = reloj();

  /// Sesión nueva (la crea el anfitrión o el invitado al recibir PARTIDA_NUEVA).
  factory SesionPartidaRed.nueva({
    required RolRed rol,
    String? idPartida,
    int? semilla,
    String nivel = 'campus',
    bool anfitrionEmpieza = true,
    DateTime Function()? reloj,
    EstadoSesionRed estado = EstadoSesionRed.enJuego,
  }) {
    final n = normalizarNivelRed(nivel);
    if (n == null) throw FormatException('Nivel desconocido: $nivel');
    return SesionPartidaRed._(
      idPartida: idPartida ?? Sobre.nuevaSesion(),
      semilla: semilla ?? Random.secure().nextInt(0x7fffffff),
      nivel: n,
      anfitrionEmpieza: anfitrionEmpieza,
      rol: rol,
      reloj: reloj ?? DateTime.now,
      estado: estado,
    );
  }

  static List<Carta> _construirTablero(String nivel, int semilla) =>
      List<Carta>.of(MotorJuego.crearPartida(
        nivel: nivel,
        modo: 'relajado',
        semilla: semilla,
        configuracion: const ConfiguracionPartida(),
      ).tablero);

  final String idPartida;
  final int semilla;
  final String nivel;
  final bool anfitrionEmpieza;
  final DateTime Function() reloj;

  /// Rol de este dispositivo.
  RolRed rol;
  EstadoSesionRed estado;
  final List<Carta> tablero;
  RolRed turno;
  DateTime actualizada;

  /// `anfitrion`, `invitado`, `empate`, `desconocido` o `null` si sigue.
  String? resultado;

  /// `completa`, `abandono` o `sesion`.
  String? motivoFin;

  final List<JugadaRed> jugadas = [];
  final Map<RolRed, int> ultimoSeq = {RolRed.anfitrion: 0, RolRed.invitado: 0};
  final Map<RolRed, int> puntos = {RolRed.anfitrion: 0, RolRed.invitado: 0};

  int get filas => nivel == 'laboratorio' ? 6 : 4;
  int get columnas => filas;
  RolRed get jugadorLocal => rol;
  bool get esMiTurno => turno == rol;
  int get totalJugadas => jugadas.length;
  int get puntosLocales => puntos[rol]!;
  int get puntosRival => puntos[rol.rival]!;
  bool get finalizada =>
      estado == EstadoSesionRed.terminada || estado == EstadoSesionRed.abandonada;

  List<int> get visibles => [
        for (var i = 0; i < tablero.length; i++)
          if (tablero[i].estado == EstadoCarta.visible) i,
      ];
  bool get esperandoOcultar => visibles.length >= 2;
  bool get todoEmparejado => tablero.every((c) => c.estado == EstadoCarta.emparejada);

  int seqSiguiente(RolRed j) => ultimoSeq[j]! + 1;

  /// Valida sin modificar. Orden: duplicado, sesión, índice, turno, carta.
  ResultadoJugadaRed validar(RolRed jugador, int indice, int seq) {
    if (seq <= ultimoSeq[jugador]!) return ResultadoJugadaRed.duplicada;
    if (estado != EstadoSesionRed.enJuego) {
      return const ResultadoJugadaRed.rechazada('La partida no está en curso.',
          codigo: 'sesion');
    }
    if (indice < 0 || indice >= tablero.length) {
      return ResultadoJugadaRed.rechazada('Índice $indice fuera de rango.');
    }
    if (jugador != turno) {
      return const ResultadoJugadaRed.rechazada('No es el turno de ese jugador.',
          codigo: 'turno');
    }
    if (esperandoOcultar) {
      return const ResultadoJugadaRed.rechazada('Espera a que se oculten las cartas.');
    }
    if (tablero[indice].estado != EstadoCarta.oculta) {
      return ResultadoJugadaRed.rechazada('La carta $indice ya está volteada o emparejada.');
    }
    return const ResultadoJugadaRed.aplicada();
  }

  /// Valida y aplica una jugada. Un `seq` repetido se ignora.
  ResultadoJugadaRed aplicarJugada(RolRed jugador, int indice, int seq) {
    final v = validar(jugador, indice, seq);
    if (!v.aceptada) return v;
    tablero[indice] = tablero[indice].copyWith(estado: EstadoCarta.visible);
    ultimoSeq[jugador] = seq;
    jugadas.add(JugadaRed(jugador, indice, seq));
    actualizada = reloj();
    final vis = visibles;
    if (vis.length == 1) {
      return const ResultadoJugadaRed.aplicada(esPrimera: true);
    }
    final a = tablero[vis[0]], b = tablero[vis[1]];
    if (a.simboloId == b.simboloId) {
      for (final i in vis) {
        tablero[i] = tablero[i].copyWith(estado: EstadoCarta.emparejada);
      }
      puntos[jugador] = puntos[jugador]! + 1;
      if (todoEmparejado) {
        _terminar();
        return const ResultadoJugadaRed.aplicada(acierto: true, terminada: true);
      }
      return const ResultadoJugadaRed.aplicada(acierto: true);
    }
    turno = jugador.rival;
    return const ResultadoJugadaRed.aplicada();
  }

  void _terminar() {
    final a = puntos[RolRed.anfitrion]!, i = puntos[RolRed.invitado]!;
    resultado = a == i ? 'empate' : (a > i ? 'anfitrion' : 'invitado');
    motivoFin = 'completa';
    estado = EstadoSesionRed.terminada;
  }

  /// Oculta las dos cartas de un fallo.
  void ocultarPendientes() {
    if (!esperandoOcultar) return;
    for (final i in visibles) {
      tablero[i] = tablero[i].copyWith(estado: EstadoCarta.oculta);
    }
    actualizada = reloj();
  }

  void marcarConectando() {
    if (!finalizada) estado = EstadoSesionRed.conectando;
  }

  void iniciar() {
    if (!finalizada) estado = EstadoSesionRed.enJuego;
  }

  void pausarPorDesconexion() {
    if (estado == EstadoSesionRed.enJuego || estado == EstadoSesionRed.conectando) {
      estado = EstadoSesionRed.pausadaPorDesconexion;
      actualizada = reloj();
    }
  }

  void reanudar() {
    if (!finalizada) estado = EstadoSesionRed.enJuego;
  }

  void abandonar() {
    if (estado == EstadoSesionRed.terminada) return;
    estado = EstadoSesionRed.abandonada;
    motivoFin = 'abandono';
    actualizada = reloj();
  }

  /// Cierra la partida por un `FIN` recibido.
  void terminarPorFin(String? ganador, {String motivo = 'completa'}) {
    if (estado == EstadoSesionRed.terminada) return;
    resultado = ganador ?? 'desconocido';
    motivoFin = motivo;
    estado = EstadoSesionRed.terminada;
    actualizada = reloj();
  }

  /// Decide la respuesta del anfitrión a `REANUDAR`.
  ResultadoReanudar procesarReanudar(String id, int ultimoSeqRemoto) {
    if (id != idPartida) return ResultadoReanudar.sesionDesconocida;
    if (finalizada) return ResultadoReanudar.partidaTerminada;
    return ResultadoReanudar.enviarEstado;
  }

  /// Texto del resultado visto desde este dispositivo.
  String descripcionResultado() {
    final marcador = '$puntosLocales a $puntosRival';
    if (estado == EstadoSesionRed.abandonada) return 'abandonada ($marcador)';
    if (resultado == 'desconocido') return 'ya no está disponible';
    if (resultado == 'empate') return 'empate ($marcador)';
    if (resultado == null) return 'sin resultado';
    return resultado == rol.name ? 'ganaste ($marcador)' : 'ganó el rival ($marcador)';
  }

  Map<String, Object?> toJson() => {
        'v': 1,
        'idPartida': idPartida,
        'semilla': semilla,
        'nivel': nivel,
        'anfitrionEmpieza': anfitrionEmpieza,
        'jugadas': [for (final j in jugadas) j.aJson()],
        'seq': {for (final r in RolRed.values) r.name: ultimoSeq[r]},
        'turno': turno.name,
        'puntajes': {for (final r in RolRed.values) r.name: puntos[r]},
        'estado': estado.name,
        'rol': rol.name,
        'resultado': resultado,
        'motivoFin': motivoFin,
        'ts': actualizada.toIso8601String(),
      };

  /// Reconstruye reproduciendo las jugadas. [rol] reemplaza al de la
  /// instantánea (el invitado recibe la del anfitrión). Lanza [FormatException]
  /// si es inconsistente.
  factory SesionPartidaRed.desdeJson(
    Map<String, Object?> json, {
    RolRed? rol,
    DateTime Function()? reloj,
    bool ocultar = true,
  }) {
    try {
      final id = json['idPartida'];
      final semilla = json['semilla'];
      final nivel = normalizarNivelRed(json['nivel']);
      final miRol = rol ?? RolRed.desdeNombre(json['rol']);
      if (id is! String || semilla is! int || nivel == null || miRol == null) {
        throw const FormatException('Instantánea incompleta.');
      }
      final s = SesionPartidaRed._(
        idPartida: id,
        semilla: semilla,
        nivel: nivel,
        anfitrionEmpieza: json['anfitrionEmpieza'] as bool? ?? true,
        rol: miRol,
        reloj: reloj ?? DateTime.now,
        estado: EstadoSesionRed.enJuego,
      );
      for (final raw in (json['jugadas'] as List? ?? const [])) {
        final m = raw as Map;
        final j = RolRed.desdeNombre(m['j']);
        if (j == null) throw const FormatException('Jugador inválido.');
        if (s.esperandoOcultar) s.ocultarPendientes();
        final r = s.aplicarJugada(j, m['i'] as int, m['s'] as int);
        if (!r.aceptada) {
          throw FormatException('Jugada inconsistente: ${r.motivo ?? 'duplicada'}');
        }
      }
      if (ocultar) s.ocultarPendientes();
      final turnoJson = RolRed.desdeNombre(json['turno']);
      if (s.estado != EstadoSesionRed.terminada && turnoJson != null && turnoJson != s.turno) {
        throw const FormatException('Turno inconsistente.');
      }
      final pj = json['puntajes'] as Map?;
      if (pj != null) {
        for (final r in RolRed.values) {
          if (pj[r.name] != s.puntos[r]) throw const FormatException('Puntajes inconsistentes.');
        }
      }
      // Reemplaza el estado derivado por el guardado (pausa, abandono, FIN).
      final estado = EstadoSesionRed.desdeNombre(json['estado']);
      s.estado = estado == EstadoSesionRed.enJuego ? EstadoSesionRed.pausadaPorDesconexion : estado;
      if (s.estado == EstadoSesionRed.terminada || s.estado == EstadoSesionRed.abandonada) {
        s.resultado = json['resultado'] as String? ?? s.resultado;
        s.motivoFin = json['motivoFin'] as String? ?? s.motivoFin;
      }
      s.actualizada = DateTime.tryParse(json['ts'] as String? ?? '') ?? s.actualizada;
      return s;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Instantánea inválida: $e');
    }
  }
}
