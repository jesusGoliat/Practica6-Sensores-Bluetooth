import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../dominio/configuracion_partida.dart';
import '../dominio/error_partida.dart';
import '../dominio/estado_partida.dart';
import '../dominio/motor_juego.dart';
import 'preferencias_juego.dart';
import 'repositorio_partidas.dart';
import 'sonido_service.dart';

/// Orquesta la partida, el reloj, el autoguardado y la lista de partidas.
/// La interfaz solo observa este ChangeNotifier.
class EstadoJuego extends ChangeNotifier {
  EstadoJuego({
    required RepositorioPartidas repositorio,
    required PreferenciasJuego preferencias,
    required SonidoService sonido,
    required Directory temporales,
  })  : _repo = repositorio,
        _prefs = preferencias,
        _sonido = sonido,
        _temporales = temporales;

  final RepositorioPartidas _repo;
  final PreferenciasJuego _prefs;
  final SonidoService _sonido;
  final Directory _temporales;

  EstadoPartida? partida;
  MotorJuego? motor;
  List<PartidaGuardada> partidas = <PartidaGuardada>[];
  EstadoPartida? autoguardado;
  ProgresoJuego progreso = ProgresoJuego();

  String formato = 'json';
  bool sonidoActivo = true;
  bool animaciones = true;
  String nombreJugador = 'Jugador IPN';
  String nivelPreferido = 'campus';
  String modoPreferido = 'relajado';

  bool pausado = false;
  bool esperandoOcultar = false;
  bool inicializado = false;
  String? aviso;
  ResultadoIntento? ultimoResultado;
  int versionEvento = 0;

  Timer? _reloj;
  Timer? _ocultar;
  Timer? _debounce;
  int _segundos = 0;
  bool _guardadaFinal = false;

  bool get activa => partida != null && !partida!.terminada;
  bool get victoria => partida?.victoria ?? false;
  bool get derrota => partida?.terminada == true && partida?.perdida == true;
  bool get hayAutoguardado => autoguardado != null;
  int get segundos => _segundos;

  Future<void> iniciar() async {
    formato = _prefs.formato;
    sonidoActivo = _prefs.sonido;
    animaciones = _prefs.animaciones;
    nombreJugador = _prefs.nombreJugador;
    nivelPreferido = _prefs.ultimoNivel;
    modoPreferido = _prefs.ultimoModo;
    progreso = _prefs.progreso;
    _sonido.habilitado = sonidoActivo;
    partidas = await _repo.listar();
    autoguardado = await _repo.cargarAutoguardado();
    inicializado = true;
    notifyListeners();
  }

  void nuevaPartida({String? nivel, String? modo}) {
    _detenerReloj();
    _ocultar?.cancel();
    _debounce?.cancel();
    nivelPreferido = nivel ?? nivelPreferido;
    modoPreferido = modo ?? modoPreferido;
    final semilla = DateTime.now().microsecondsSinceEpoch % 2147483647;
    final config = ConfiguracionPartida(
      nombreJugador: nombreJugador,
      sonido: sonidoActivo,
      animaciones: animaciones,
      formatoPreferido: formato,
      tema: _prefs.tema,
    );
    motor = MotorJuego(MotorJuego.crearPartida(
      nivel: nivelPreferido,
      modo: modoPreferido,
      semilla: semilla,
      configuracion: config,
    ));
    partida = motor!.partida;
    _segundos = 0;
    pausado = false;
    esperandoOcultar = false;
    _guardadaFinal = false;
    ultimoResultado = null;
    _prefs.setUltimoNivel(nivelPreferido);
    _prefs.setUltimoModo(modoPreferido);
    _iniciarReloj();
    _programarAutoguardado();
    notifyListeners();
  }

  void continuarAutoguardado() {
    final guardada = autoguardado;
    if (guardada == null) return;
    _detenerReloj();
    motor = MotorJuego(guardada);
    partida = guardada;
    _segundos = guardada.tiempoSegundos;
    pausado = false;
    esperandoOcultar = false;
    _guardadaFinal = false;
    autoguardado = null;
    _iniciarReloj();
    notifyListeners();
  }

  Future<void> cargar(PartidaGuardada guardada) async {
    final estado = await _repo.cargar(guardada);
    _detenerReloj();
    motor = MotorJuego(estado);
    partida = estado;
    _segundos = estado.tiempoSegundos;
    pausado = false;
    esperandoOcultar = false;
    _guardadaFinal = estado.terminada;
    if (!estado.terminada) _iniciarReloj();
    notifyListeners();
  }

  void voltear(int indice) {
    if (partida == null || motor == null) return;
    if (pausado || esperandoOcultar || partida!.terminada) return;
    final resultado = motor!.seleccionar(indice);
    if (resultado == null) return;
    partida = motor!.partida;
    ultimoResultado = resultado;
    versionEvento++;
    if (resultado.esPrimera) {
      _sonido.reproducir('voltear');
    } else if (resultado.acierto) {
      _sonido.reproducir('acierto');
      if (resultado.categoriaCompletada != null) {
        aviso = '¡Categoría completada! +150 puntos';
      }
      if (resultado.victoria) {
        _sonido.reproducir('victoria');
        _finalizar();
      }
    } else {
      _sonido.reproducir('error');
      esperandoOcultar = true;
      _ocultar?.cancel();
      _ocultar = Timer(const Duration(milliseconds: 850), () {
        motor?.ocultarPendientes();
        partida = motor?.partida;
        esperandoOcultar = false;
        notifyListeners();
      });
    }
    _programarAutoguardado();
    notifyListeners();
  }

  void pausar() {
    if (pausado || partida == null || partida!.terminada) return;
    pausado = true;
    _detenerReloj();
    notifyListeners();
  }

  void reanudar() {
    if (!pausado) return;
    pausado = false;
    _iniciarReloj();
    notifyListeners();
  }

  void reiniciar() {
    nuevaPartida(nivel: partida?.nivel, modo: partida?.modo);
  }

  Future<void> guardar({String? nombre, String? formatoElegido, String? etiqueta}) async {
    final actual = partida;
    if (actual == null) return;
    final elegido = formatoElegido ?? formato;
    final conEtiqueta = actual.copyWith(
      etiqueta: etiqueta ?? actual.etiqueta,
      configuracion: actual.configuracion.copyWith(
        nombreJugador: nombreJugador,
        sonido: sonidoActivo,
        animaciones: animaciones,
        formatoPreferido: elegido,
      ),
      actualizada: DateTime.now(),
    );
    final guardada = await _repo.guardar(
      conEtiqueta,
      formato: elegido,
      nombre: nombre,
    );
    partida = conEtiqueta;
    motor?.reemplazar(conEtiqueta);
    await refrescarPartidas();
    aviso = 'Partida guardada como ${p.basename(guardada.archivo.path)}';
    notifyListeners();
  }

  Future<void> eliminar(PartidaGuardada guardada) async {
    await _repo.eliminar(guardada);
    await refrescarPartidas();
    notifyListeners();
  }

  Future<void> actualizarEtiqueta(PartidaGuardada guardada, String etiqueta) async {
    await _repo.actualizarEtiqueta(guardada, etiqueta.trim());
    await refrescarPartidas();
    notifyListeners();
  }

  Future<String> contenido(PartidaGuardada guardada) => _repo.contenidoCrudo(guardada);

  Future<void> refrescarPartidas() async {
    partidas = await _repo.listar();
    notifyListeners();
  }

  Future<void> importar() async {
    final archivos = await FilePicker.pickFiles(type: FileType.any);
    if (archivos.isEmpty) return;
    final elegido = archivos.first;
    final bytes = await elegido.readAsBytes();
    await _temporales.create(recursive: true);
    final temp = File(p.join(_temporales.path, 'importar_${DateTime.now().microsecondsSinceEpoch}_${elegido.name}'));
    await temp.writeAsBytes(bytes, flush: true);
    try {
      await _repo.importar(temp, elegido.name);
      await refrescarPartidas();
      aviso = 'Partida importada: ${elegido.name}';
    } on ErrorPartida catch (e) {
      aviso = e.mensaje;
    } finally {
      if (await temp.exists()) await temp.delete();
      notifyListeners();
    }
  }

  Future<void> configurarFormato(String valor) async {
    formato = valor;
    await _prefs.setFormato(valor);
    notifyListeners();
  }

  Future<void> configurarSonido(bool valor) async {
    sonidoActivo = valor;
    _sonido.habilitado = valor;
    await _prefs.setSonido(valor);
    notifyListeners();
  }

  Future<void> probarSonido() => _sonido.reproducir('acierto');

  Future<void> configurarAnimaciones(bool valor) async {
    animaciones = valor;
    await _prefs.setAnimaciones(valor);
    notifyListeners();
  }

  Future<void> configurarNombre(String valor) async {
    nombreJugador = valor.trim().isEmpty ? 'Jugador IPN' : valor.trim();
    await _prefs.setNombreJugador(nombreJugador);
    notifyListeners();
  }

  /// Se llama al pasar la app a segundo plano o al salir de la pantalla.
  Future<void> autoguardarAhora() async {
    _debounce?.cancel();
    final actual = partida;
    if (actual == null) return;
    if (actual.terminada) {
      await _repo.borrarAutoguardado();
    } else {
      await _repo.guardarAutoguardado(actual);
      autoguardado = actual;
    }
  }

  void limpiarAviso() {
    aviso = null;
    notifyListeners();
  }

  /// Detiene reloj y temporizadores pendientes (útil al salir o en pruebas).
  void detenerTemporizadores() {
    _detenerReloj();
    _ocultar?.cancel();
    _debounce?.cancel();
  }

  void _iniciarReloj() {
    _detenerReloj();
    if (partida == null || partida!.terminada) return;
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _detenerReloj() {
    _reloj?.cancel();
    _reloj = null;
  }

  void _tick() {
    if (partida == null || pausado || partida!.terminada) return;
    _segundos++;
    final agotado = motor?.actualizarTiempo(_segundos) ?? false;
    partida = motor?.partida ?? partida;
    if (agotado) {
      _sonido.reproducir('error');
      _finalizar();
    } else {
      notifyListeners();
    }
  }

  Future<void> _finalizar() async {
    _detenerReloj();
    final actual = partida;
    if (actual == null) return;
    if (!_guardadaFinal) {
      _guardadaFinal = true;
      progreso = await _prefs.registrarResultado(actual);
      try {
        await _repo.guardar(actual, formato: formato, nombre: 'partida_${actual.id}');
      } catch (_) {
        // Aunque falle el guardado final, el estado en memoria se conserva.
      }
      await _repo.borrarAutoguardado();
      autoguardado = null;
      await refrescarPartidas();
    }
    notifyListeners();
  }

  void _programarAutoguardado() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final actual = partida;
      if (actual == null) return;
      if (actual.terminada) return;
      await _repo.guardarAutoguardado(actual);
      autoguardado = actual;
    });
  }

  /// Exporta los bytes de una partida en el formato indicado. La UI decide
  /// dónde guardarlos con el selector del sistema.
  Future<Uint8List> bytesExportar(String formatoElegido) async {
    final actual = partida;
    if (actual == null) return Uint8List(0);
    final bytes = await _repo.bytesParaExportar(actual, formatoElegido);
    return Uint8List.fromList(bytes);
  }

  @override
  void dispose() {
    _detenerReloj();
    _ocultar?.cancel();
    _debounce?.cancel();
    _sonido.dispose();
    super.dispose();
  }
}
