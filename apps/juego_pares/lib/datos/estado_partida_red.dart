import 'dart:async';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/foundation.dart';

import '../dominio/partida_red.dart';
import 'puente_ble.dart';
import 'repositorio_partida_red.dart';

/// Fase de la pantalla Bluetooth.
enum FaseRed { inicio, anunciando, buscando, enPartida }

/// Petición de un invitado pendiente de aceptar.
class SolicitudRed {
  const SolicitudRed(this.nombre, this.sesionEnlace);
  final String nombre;
  final String sesionEnlace;
}

class _DuplicadosAvisados extends ControlDuplicados {
  _DuplicadosAvisados(this.alDuplicado);
  final void Function(String sesion, int seq) alDuplicado;

  @override
  bool esNuevo(String canal, String sesion, int seq) {
    final nuevo = super.esNuevo(canal, sesion, seq);
    if (!nuevo) alDuplicado(sesion, seq);
    return nuevo;
  }
}

/// Orquesta una partida por Bluetooth: anuncio/escaneo, handshake, jugadas,
/// desconexión, reanudación y persistencia. La UI solo observa este objeto.
class EstadoPartidaRed extends ChangeNotifier {
  EstadoPartidaRed({
    required PuenteBle puente,
    required RepositorioPartidaRed repositorio,
    this.nombreLocal = 'Jugador IPN',
    this.retardoOcultar = const Duration(milliseconds: 850),
    this.tiempoAck = const Duration(seconds: 3),
    this.reintentosAck = 3,
  })  : _puente = puente,
        _repo = repositorio;

  final PuenteBle _puente;
  final RepositorioPartidaRed _repo;
  final Duration retardoOcultar;
  final Duration tiempoAck;
  final int reintentosAck;

  String nombreLocal;
  String? nombreRival;

  FaseRed fase = FaseRed.inicio;
  RolRed? rolElegido;
  SesionPartidaRed? sesion;
  SesionPartidaRed? pendiente;
  EstadoBluetooth? bt;
  String? mensajeBt;
  List<DispositivoEncontrado> dispositivos = [];
  bool escaneando = false;
  bool conectando = false;
  SolicitudRed? solicitud;
  String? aviso;
  String? mensajeRival;
  bool _liberado = false;

  final List<String> registro = [];
  static const int maxRegistro = 30;

  Enlace? _enlace;
  StreamSubscription<Sobre>? _subMsgs;
  StreamSubscription<EstadoConexion>? _subEstado;
  StreamSubscription<ErrorProtocolo>? _subErr;
  StreamSubscription<TransporteBytes>? _subConexiones;
  StreamSubscription<DispositivoEncontrado>? _subEscaneo;
  String _sesionEnlace = '00000000';
  DispositivoEncontrado? _ultimoDispositivo;
  Sobre? _ultimaJugadaEnviada;
  Timer? _temporizadorOcultar;
  bool _enviando = false;
  bool _finEnviado = false;
  bool _saliendo = false;
  Future<void> _colaGuardado = Future.value();
  int _idCrudo = 0xF000;

  bool get conectado => _enlace?.estadoActual == EstadoConexion.conectado;
  bool get hayPartida => sesion != null;
  bool get puedeJugar =>
      sesion != null && sesion!.estado == EstadoSesionRed.enJuego && conectado;
  String? get nombreAnuncio => _puente.nombreAnuncio;

  // ---------------------------------------------------------------- registro

  void _log(String texto) {
    final t = DateTime.now();
    String d(int n) => n.toString().padLeft(2, '0');
    registro.add('${d(t.hour)}:${d(t.minute)}:${d(t.second)} $texto');
    if (registro.length > maxRegistro) {
      registro.removeRange(0, registro.length - maxRegistro);
    }
    _notificar();
  }

  void _notificar() {
    if (!_liberado) notifyListeners();
  }

  void limpiarAviso() {
    aviso = null;
    _notificar();
  }

  // -------------------------------------------------------------- persistencia

  /// Busca una partida guardada al abrir la app.
  Future<void> cargarPendiente() async {
    try {
      final json = await _repo.cargar();
      if (json == null) return;
      final s = SesionPartidaRed.desdeJson(json);
      if (sesion == null) {
        pendiente = s;
        _log('Partida guardada encontrada: ${s.idPartida}');
      }
    } catch (e) {
      try {
        await _repo.borrar();
      } catch (_) {}
      _log('Se descartó una partida guardada dañada.');
    }
  }

  Future<void> _persistir() {
    final s = sesion;
    if (s == null) return Future.value();
    final json = s.toJson();
    _colaGuardado = _colaGuardado.then((_) async {
      try {
        await _repo.guardar(json);
      } catch (e) {
        _log('No se pudo guardar la partida: $e');
      }
    });
    return _colaGuardado;
  }

  Future<void> _borrarGuardado() {
    _colaGuardado = _colaGuardado.then((_) async {
      try {
        await _repo.borrar();
      } catch (_) {}
    });
    return _colaGuardado;
  }

  Future<void> descartarPendiente() async {
    pendiente = null;
    await _borrarGuardado();
    _log('Partida guardada descartada.');
  }

  /// Retoma la partida guardada y busca al otro jugador.
  Future<void> recuperar() async {
    final s = pendiente;
    if (s == null) return;
    pendiente = null;
    if (!s.finalizada) s.estado = EstadoSesionRed.pausadaPorDesconexion;
    sesion = s;
    rolElegido = s.rol;
    fase = FaseRed.enPartida;
    _finEnviado = false;
    _log('Partida ${s.idPartida} recuperada como ${s.rol.name}.');
    await reintentarConexion();
  }

  // ------------------------------------------------------------ rol anfitrión

  Future<void> iniciarAnfitrion() async {
    if (fase != FaseRed.inicio) return;
    rolElegido = RolRed.anfitrion;
    await _levantarAnuncio(primera: true);
  }

  Future<void> _levantarAnuncio({bool primera = false}) async {
    mensajeBt = null;
    final estado = await _puente.iniciarAnuncio();
    bt = estado;
    if (!estado.disponible || !_puente.anunciando) {
      mensajeBt = estado.disponible ? _puente.mensajeError : estado.mensaje;
      if (primera && sesion == null) {
        fase = FaseRed.inicio;
        rolElegido = null;
      }
      _log('No se pudo anunciar: ${mensajeBt ?? estado.name}');
      return;
    }
    _subConexiones ??= _puente.conexiones.listen(_alNuevaConexion);
    if (sesion == null) fase = FaseRed.anunciando;
    _log('Anunciando como ${_puente.nombreAnuncio ?? 'anfitrión'}.');
  }

  void _alNuevaConexion(TransporteBytes t) {
    _soltarEnlace();
    _adjuntar(t);
    _log('Un dispositivo se conectó. Esperando su saludo.');
  }

  // ------------------------------------------------------------- rol invitado

  Future<void> iniciarInvitado() async {
    if (fase != FaseRed.inicio) return;
    rolElegido = RolRed.invitado;
    mensajeBt = null;
    final estado = await _puente.permisosInvitado();
    bt = estado;
    if (!estado.disponible) {
      mensajeBt = estado.mensaje;
      rolElegido = null;
      _log('Bluetooth no disponible: ${estado.name}');
      return;
    }
    fase = FaseRed.buscando;
    await buscar();
  }

  Future<void> buscar() async {
    await _subEscaneo?.cancel();
    dispositivos = [];
    escaneando = true;
    _log('Buscando partidas cercanas…');
    _subEscaneo = _puente.escanear().listen((d) {
      dispositivos = [...dispositivos, d];
      _notificar();
    }, onDone: () {
      escaneando = false;
      if (dispositivos.isEmpty) {
        final e = _puente.mensajeErrorCliente;
        _log(e ?? 'Búsqueda terminada sin resultados.');
      }
      _notificar();
    }, onError: (Object e) {
      escaneando = false;
      _log('Error al buscar: $e');
    });
    _notificar();
  }

  Future<void> conectarCon(DispositivoEncontrado d) async {
    if (conectando) return;
    conectando = true;
    _ultimoDispositivo = d;
    await _subEscaneo?.cancel();
    escaneando = false;
    _log('Conectando con ${d.nombre.isEmpty ? d.id : d.nombre}…');
    final t = await _puente.conectar(d.id);
    conectando = false;
    if (t == null) {
      _log(_puente.mensajeErrorCliente ?? 'No se pudo conectar.');
      mensajeBt = _puente.mensajeErrorCliente;
      _notificar();
      return;
    }
    _soltarEnlace();
    _adjuntar(t);
    final s = sesion;
    if (s != null && s.rol == RolRed.invitado) {
      _sesionEnlace = s.idPartida;
      _log('Conectado. Enviando REANUDAR.');
      await _enviar(TiposMensaje.reanudar,
          {'idPartida': s.idPartida, 'ultimoSeq': s.totalJugadas});
    } else {
      _sesionEnlace = Sobre.nuevaSesion();
      _log('Conectado. Enviando HOLA.');
      await _enviar(TiposMensaje.hola, {'app': 'juego', 'nombre': nombreLocal, 'version': 1});
    }
    _notificar();
  }

  // ---------------------------------------------------------------- enlace

  void _adjuntar(TransporteBytes t) {
    final e = Enlace(
      t,
      tiempoAck: tiempoAck,
      reintentos: reintentosAck,
      duplicados: _DuplicadosAvisados((sesion, seq) {
        aviso = 'Mensaje duplicado ignorado (seq $seq)';
        _log('Mensaje duplicado ignorado (seq $seq)');
      }),
    );
    _enlace = e;
    _subMsgs = e.mensajes.listen(_alMensaje);
    _subErr = e.errores.listen((er) => _log('Mensaje inválido [${er.codigo}]: ${er.mensaje}'));
    _subEstado = e.estado.listen((s) {
      if (s == EstadoConexion.desconectado && identical(_enlace, e)) _alDesconectar();
    });
    if (e.estadoActual == EstadoConexion.desconectado) _alDesconectar();
  }

  void _soltarEnlace() {
    final e = _enlace;
    _enlace = null;
    _subMsgs?.cancel();
    _subEstado?.cancel();
    _subErr?.cancel();
    _subMsgs = _subEstado = _subErr = null;
    if (e != null) unawaited(e.cerrar().catchError((Object _) {}));
  }

  Future<Sobre?> _enviar(String tipo, Map<String, dynamic> datos,
      {String? sesionEnlace, bool? confiable}) async {
    final e = _enlace;
    if (e == null) return null;
    try {
      return await e.enviar(Canales.juego, sesionEnlace ?? _sesionEnlace, tipo, datos,
          confiable: confiable);
    } on ErrorEnlace catch (er) {
      _log('Error al enviar $tipo: ${er.mensaje}');
      if (identical(_enlace, e) && e.estadoActual != EstadoConexion.conectado) {
        _alDesconectar();
      }
      return null;
    } catch (er) {
      _log('Error al enviar $tipo: $er');
      return null;
    }
  }

  void _alDesconectar() {
    if (_saliendo || _liberado) return;
    if (_enlace == null && sesion?.estado != EstadoSesionRed.enJuego) return;
    _soltarEnlace();
    _temporizadorOcultar?.cancel();
    final s = sesion;
    solicitud = null;
    conectando = false;
    if (s != null && s.estado == EstadoSesionRed.enJuego) {
      s.pausarPorDesconexion();
      _log('Conexión perdida. Partida en pausa.');
      unawaited(_persistir());
    } else if (s == null) {
      _log('Conexión perdida antes de empezar.');
      if (rolElegido == RolRed.anfitrion) {
        unawaited(_levantarAnuncio());
      } else {
        fase = FaseRed.buscando;
      }
    }
    _notificar();
  }

  /// Tras una desconexión: el anfitrión vuelve a anunciar y el invitado busca.
  Future<void> reintentarConexion() async {
    final s = sesion;
    if (s == null || s.finalizada) return;
    _log('Reintentando conexión…');
    if (s.rol == RolRed.anfitrion) {
      await _levantarAnuncio();
    } else {
      final d = _ultimoDispositivo;
      final estado = await _puente.permisosInvitado();
      bt = estado;
      if (!estado.disponible) {
        mensajeBt = estado.mensaje;
        _log('Bluetooth no disponible: ${estado.name}');
        _notificar();
        return;
      }
      if (d != null) {
        await conectarCon(d);
        if (conectado) return;
      }
      await buscar();
    }
  }

  // --------------------------------------------------------------- mensajes

  void _alMensaje(Sobre m) {
    try {
      switch (m.tipo) {
        case TiposMensaje.hola:
          _alHola(m);
        case TiposMensaje.acepta:
          _log('El anfitrión aceptó. Esperando la partida.');
        case TiposMensaje.rechaza:
          _alRechazo(m);
        case TiposMensaje.partidaNueva:
          _alPartidaNueva(m);
        case TiposMensaje.jugada:
          _alJugada(m);
        case TiposMensaje.estado:
          _alEstado(m);
        case TiposMensaje.reanudar:
          _alReanudar(m);
        case TiposMensaje.fin:
          _alFin(m);
        case TiposMensaje.adios:
          _alAdios(m);
        case TiposMensaje.error:
          _log('El rival reportó [${m.datos['codigo']}]: ${m.datos['mensaje']}');
        case TiposMensaje.ping:
          break;
        default:
          _log('Mensaje ignorado: ${m.tipo}');
      }
    } catch (e) {
      _log('Error al procesar ${m.tipo}: $e');
    }
  }

  void _alHola(Sobre m) {
    if (rolElegido != RolRed.anfitrion) return;
    final s = sesion;
    final version = m.datos['version'];
    if (version is! int || version < 1) {
      unawaited(_rechazar(m.sesion, 'version'));
      return;
    }
    if (s != null && !s.finalizada && s.totalJugadas == 0 &&
        s.estado == EstadoSesionRed.pausadaPorDesconexion) {
      sesion = null; // partida sin jugadas: se trata como nueva
    } else if (s != null && !s.finalizada) {
      unawaited(_rechazar(m.sesion, 'partida en curso'));
      return;
    }
    if (solicitud != null) {
      unawaited(_rechazar(m.sesion, 'ocupado'));
      return;
    }
    final nombre = (m.datos['nombre'] as String?)?.trim();
    solicitud = SolicitudRed(nombre == null || nombre.isEmpty ? 'Invitado' : nombre, m.sesion);
    _log('${solicitud!.nombre} quiere unirse.');
    _notificar();
  }

  Future<void> _rechazar(String sesionEnlace, String motivo) async {
    await _enviar(TiposMensaje.rechaza, {'motivo': motivo}, sesionEnlace: sesionEnlace);
    _log('Solicitud rechazada ($motivo).');
  }

  /// El anfitrión responde al diálogo «¿Aceptar a …?».
  Future<void> responderSolicitud(bool aceptar) async {
    final sol = solicitud;
    if (sol == null) return;
    solicitud = null;
    _notificar();
    if (!aceptar) {
      await _rechazar(sol.sesionEnlace, 'anfitrión');
      _soltarEnlace();
      await _levantarAnuncio();
      return;
    }
    nombreRival = sol.nombre;
    final ok = await _enviar(TiposMensaje.acepta, {}, sesionEnlace: sol.sesionEnlace);
    if (ok == null) return;
    final s = SesionPartidaRed.nueva(rol: RolRed.anfitrion);
    sesion = s;
    fase = FaseRed.enPartida;
    _finEnviado = false;
    _sesionEnlace = s.idPartida;
    _log('Partida ${s.idPartida} creada. Empiezas tú.');
    unawaited(_persistir());
    _notificar();
    await _enviar(TiposMensaje.partidaNueva, {
      'idPartida': s.idPartida,
      'semilla': s.semilla,
      'nivel': s.nivel,
      'anfitrionEmpieza': s.anfitrionEmpieza,
    });
  }

  void _alRechazo(Sobre m) {
    final motivo = m.datos['motivo'] ?? 'sin motivo';
    mensajeRival = 'El anfitrión rechazó la solicitud ($motivo).';
    aviso = mensajeRival;
    _log('Solicitud rechazada: $motivo');
    _soltarEnlace();
    fase = FaseRed.buscando;
    _notificar();
  }

  void _alPartidaNueva(Sobre m) {
    if (rolElegido != RolRed.invitado) return;
    final d = m.datos;
    final id = d['idPartida'];
    final semilla = d['semilla'];
    if (id is! String || semilla is! int || normalizarNivelRed(d['nivel']) == null) {
      unawaited(_enviar(TiposMensaje.error, {'codigo': 'formato', 'mensaje': 'PARTIDA_NUEVA inválida'}));
      return;
    }
    final s = SesionPartidaRed.nueva(
      rol: RolRed.invitado,
      idPartida: id,
      semilla: semilla,
      nivel: d['nivel'] as String,
      anfitrionEmpieza: d['anfitrionEmpieza'] as bool? ?? true,
    );
    sesion = s;
    fase = FaseRed.enPartida;
    _finEnviado = false;
    _sesionEnlace = id;
    _log('Partida $id iniciada. ${s.esMiTurno ? 'Empiezas tú.' : 'Empieza el rival.'}');
    unawaited(_persistir());
    _notificar();
  }

  void _alJugada(Sobre m) {
    final s = sesion;
    if (s == null || m.sesion != s.idPartida) {
      unawaited(_enviar(TiposMensaje.error, {'codigo': 'sesion', 'mensaje': 'Sesión desconocida'},
          sesionEnlace: m.sesion));
      return;
    }
    final j = RolRed.desdeNombre(m.datos['jugador']);
    final indice = m.datos['indice'];
    final seq = m.datos['seq'];
    if (j == null || indice is! int || seq is! int) {
      unawaited(_enviar(TiposMensaje.error, {'codigo': 'formato', 'mensaje': 'JUGADA incompleta'}));
      return;
    }
    if (s.estado == EstadoSesionRed.enJuego && j == s.rol.rival && s.esperandoOcultar) {
      // El rival ya ocultó el fallo antes de jugar; se hace lo mismo aquí.
      _temporizadorOcultar?.cancel();
      s.ocultarPendientes();
    }
    final r = j == s.rol
        ? const ResultadoJugadaRed.rechazada('Jugador inválido.', codigo: 'turno')
        : s.aplicarJugada(j, indice, seq);
    if (r.esDuplicada) {
      aviso = 'Mensaje duplicado ignorado (seq $seq)';
      _log('Jugada duplicada ignorada (jugador ${j.name}, seq $seq)');
      _notificar();
    } else if (r.esRechazada) {
      _log('Jugada rechazada [${r.codigo}]: ${r.motivo}');
      unawaited(_enviar(TiposMensaje.error, {'codigo': r.codigo, 'mensaje': r.motivo}));
    } else {
      _tras('Rival', indice, r);
    }
    _notificar();
  }

  void _tras(String quien, int indice, ResultadoJugadaRed r) {
    final s = sesion!;
    if (r.esPrimera) {
      _log('$quien volteó la carta ${indice + 1}.');
    } else if (r.acierto) {
      _log('$quien acertó una pareja (carta ${indice + 1}). ${r.terminada ? '' : 'Conserva el turno.'}');
    } else {
      _log('$quien falló (carta ${indice + 1}). Turno de ${s.esMiTurno ? 'tu turno' : 'el rival'}.');
      _temporizadorOcultar?.cancel();
      _temporizadorOcultar = Timer(retardoOcultar, () {
        sesion?.ocultarPendientes();
        _notificar();
      });
    }
    if (r.terminada) _alTerminar();
    unawaited(_persistir());
    _notificar();
  }

  void _alTerminar() {
    final s = sesion!;
    _log('Partida terminada: ${s.descripcionResultado()}.');
    if (s.rol == RolRed.anfitrion && !_finEnviado) {
      _finEnviado = true;
      unawaited(_enviar(TiposMensaje.fin, {
        'ganador': s.resultado,
        'puntos': {for (final r in RolRed.values) r.name: s.puntos[r]},
        'motivo': 'completa',
      }));
    }
  }

  void _alEstado(Sobre m) {
    if (rolElegido != RolRed.invitado) return;
    final snap = m.datos['snapshot'];
    if (snap is! Map) return;
    try {
      final s = SesionPartidaRed.desdeJson(Map<String, Object?>.from(snap), rol: RolRed.invitado);
      _temporizadorOcultar?.cancel();
      if (!s.finalizada) s.reanudar();
      sesion = s;
      fase = FaseRed.enPartida;
      _sesionEnlace = s.idPartida;
      _log('Estado del anfitrión recibido (${s.totalJugadas} jugadas). Partida reanudada.');
      unawaited(_persistir());
    } on FormatException catch (e) {
      _log('ESTADO inválido: ${e.message}');
    }
    _notificar();
  }

  void _alReanudar(Sobre m) {
    if (rolElegido != RolRed.anfitrion) return;
    final id = m.datos['idPartida'];
    final ultimo = m.datos['ultimoSeq'];
    final s = sesion;
    final r = s == null
        ? ResultadoReanudar.sesionDesconocida
        : s.procesarReanudar(id is String ? id : '', ultimo is int ? ultimo : 0);
    switch (r) {
      case ResultadoReanudar.sesionDesconocida:
        _log('REANUDAR de una partida desconocida ($id).');
        unawaited(_enviar(TiposMensaje.fin,
            {'ganador': null, 'puntos': {}, 'motivo': 'sesion'}, sesionEnlace: m.sesion));
      case ResultadoReanudar.partidaTerminada:
        _log('REANUDAR de una partida ya terminada.');
        unawaited(_enviar(TiposMensaje.fin, {
          'ganador': s!.resultado,
          'puntos': {for (final x in RolRed.values) x.name: s.puntos[x]},
          'motivo': s.estado == EstadoSesionRed.abandonada ? 'abandono' : 'completa',
        }, sesionEnlace: m.sesion));
      case ResultadoReanudar.enviarEstado:
        _temporizadorOcultar?.cancel();
        s!.ocultarPendientes();
        s.reanudar();
        fase = FaseRed.enPartida;
        _sesionEnlace = s.idPartida;
        _log('REANUDAR recibido (rival en ${ultimo ?? '?'} jugadas, yo en ${s.totalJugadas}). Enviando ESTADO.');
        unawaited(_enviar(TiposMensaje.estado, {'snapshot': s.toJson()}, sesionEnlace: s.idPartida));
        unawaited(_persistir());
    }
    _notificar();
  }

  void _alFin(Sobre m) {
    final s = sesion;
    final motivo = m.datos['motivo'] as String? ?? 'completa';
    if (s == null) return;
    if (motivo == 'sesion') {
      s.terminarPorFin(null, motivo: 'sesion');
      mensajeRival = 'La partida terminó (el anfitrión ya no la tiene).';
    } else if (motivo == 'abandono') {
      s.abandonar();
      mensajeRival = 'La partida terminó: el otro jugador salió.';
    } else if (!s.finalizada) {
      s.terminarPorFin(m.datos['ganador'] as String?, motivo: motivo);
    }
    _log('FIN recibido: ${s.descripcionResultado()}.');
    _soltarEnlace();
    unawaited(_persistir());
    _notificar();
  }

  void _alAdios(Sobre m) {
    final s = sesion;
    mensajeRival = 'El otro jugador salió';
    aviso = mensajeRival;
    _log('El otro jugador salió.');
    _soltarEnlace();
    if (s != null && !s.finalizada) {
      s.abandonar();
      unawaited(_persistir());
    } else if (s == null) {
      fase = rolElegido == RolRed.anfitrion ? FaseRed.anunciando : FaseRed.buscando;
      if (rolElegido == RolRed.anfitrion) unawaited(_levantarAnuncio());
    }
    _notificar();
  }

  // ------------------------------------------------------------ jugada local

  /// Toque (o giro) sobre una carta: valida, envía y aplica.
  Future<void> jugarLocal(int indice) async {
    final s = sesion;
    if (s == null || _enviando) return;
    final seq = s.seqSiguiente(s.rol);
    final v = s.validar(s.rol, indice, seq);
    if (!v.aceptada) {
      if (v.codigo == 'turno') {
        aviso = 'No es tu turno';
      } else if (v.esRechazada) {
        aviso = v.motivo;
      }
      _notificar();
      return;
    }
    if (!puedeJugar) {
      aviso = 'Sin conexión con el otro jugador';
      _notificar();
      return;
    }
    _enviando = true;
    try {
      final sobre = await _enviar(TiposMensaje.jugada, {
        'indice': indice,
        'jugador': s.rol.name,
        'turno': s.totalJugadas,
        'seq': seq,
      });
      if (sobre == null || !identical(s, sesion)) return;
      _ultimaJugadaEnviada = sobre;
      final r = s.aplicarJugada(s.rol, indice, seq);
      if (r.aceptada) _tras('Tú', indice, r);
    } finally {
      _enviando = false;
    }
  }

  // ------------------------------------------------------------- diagnóstico

  Future<void> _enviarCrudo(Sobre sobre) async {
    final e = _enlace;
    if (e == null || e.estadoActual != EstadoConexion.conectado) {
      _log('Sin conexión para el envío de prueba.');
      return;
    }
    final t = e.transporte;
    final frag = Fragmentador(t.maxFragmento, idInicial: _idCrudo);
    _idCrudo = (_idCrudo + 1) & 0xFFFF;
    for (final f in frag.fragmentar(Uint8List.fromList(sobre.toBytes()))) {
      await t.enviar(f);
    }
  }

  /// Reenvía la última JUGADA con el mismo seq (demuestra el control de duplicados).
  Future<void> reenviarUltimaJugada() async {
    final u = _ultimaJugadaEnviada;
    if (u == null) {
      _log('Aún no hay una jugada enviada que reenviar.');
      return;
    }
    _log('Reenviando JUGADA (seq ${u.seq}) para probar duplicados.');
    try {
      await _enviarCrudo(u);
    } catch (e) {
      _log('No se pudo reenviar: $e');
    }
  }

  Future<void> enviarJugadaFueraDeTurno() async {
    final s = sesion;
    if (s == null || !puedeJugar) return;
    if (s.esMiTurno) {
      _log('Es tu turno: espera al turno del rival para probar «fuera de turno».');
      return;
    }
    final i = s.tablero.indexWhere((c) => c.estado.name == 'oculta');
    await _enviar(TiposMensaje.jugada, {
      'indice': i < 0 ? 0 : i,
      'jugador': s.rol.name,
      'turno': s.totalJugadas,
      'seq': s.seqSiguiente(s.rol),
    });
    _log('JUGADA fuera de turno enviada.');
  }

  Future<void> enviarJugadaInvalida() async {
    final s = sesion;
    if (s == null || !puedeJugar) return;
    await _enviar(TiposMensaje.jugada, {
      'indice': 999,
      'jugador': s.rol.name,
      'turno': s.totalJugadas,
      'seq': s.seqSiguiente(s.rol),
    });
    _log('JUGADA con índice 999 enviada.');
  }

  Future<void> enviarVersionDistinta() async {
    final s = sesion;
    if (s == null) return;
    try {
      await _enviarCrudo(Sobre(
          v: 2, canal: Canales.juego, sesion: s.idPartida, seq: 900, tipo: TiposMensaje.ping));
      _log('Sobre con v:2 enviado.');
    } catch (e) {
      _log('No se pudo enviar: $e');
    }
  }

  // ------------------------------------------------------------------ salida

  /// «Salir»: avisa con ADIOS, deja la partida y vuelve al inicio.
  Future<void> salir() async {
    _saliendo = true;
    final s = sesion;
    if (s != null && !s.finalizada && conectado) {
      await _enviar(TiposMensaje.adios, {'motivo': 'abandono'})
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    }
    await _reiniciarTodo();
    _saliendo = false;
    _log('Saliste de la partida.');
  }

  /// Acepta el resultado final o el aviso de abandono y vuelve al inicio.
  Future<void> cerrarPartida() async {
    _saliendo = true;
    await _reiniciarTodo();
    _saliendo = false;
  }

  /// Cancela el rol elegido antes de jugar.
  Future<void> cancelarRol() async {
    _saliendo = true;
    await _reiniciarTodo(borrar: false);
    _saliendo = false;
  }

  Future<void> _reiniciarTodo({bool borrar = true}) async {
    _temporizadorOcultar?.cancel();
    await _subEscaneo?.cancel();
    _subEscaneo = null;
    _soltarEnlace();
    try {
      await _puente.detenerAnuncio();
    } catch (_) {}
    if (borrar && sesion != null) await _borrarGuardado();
    sesion = null;
    solicitud = null;
    fase = FaseRed.inicio;
    rolElegido = null;
    dispositivos = [];
    escaneando = false;
    conectando = false;
    nombreRival = null;
    _ultimoDispositivo = null;
    _ultimaJugadaEnviada = null;
    _enviando = false;
    _notificar();
  }

  Future<void> abrirAjustes() => _puente.abrirAjustes();

  @override
  void dispose() {
    _liberado = true;
    _temporizadorOcultar?.cancel();
    _subEscaneo?.cancel();
    _subConexiones?.cancel();
    _soltarEnlace();
    unawaited(_puente.liberar().catchError((Object _) {}));
    super.dispose();
  }
}
