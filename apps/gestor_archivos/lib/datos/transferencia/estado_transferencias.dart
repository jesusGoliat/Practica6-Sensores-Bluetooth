import 'dart:async';
import 'dart:io';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/foundation.dart';

import '../../dominio/modelos.dart';
import '../../dominio/transferencia/cola_transferencias.dart';
import '../../dominio/transferencia/estado_transferencia.dart';
import '../../dominio/transferencia/historial_transferencias.dart';
import '../../dominio/transferencia/metadatos_archivo.dart';
import '../../dominio/transferencia/registro_transferencia.dart';
import '../../dominio/transferencia/validador_transferencia.dart';
import '../ajustes_app.dart';
import '../servicio_archivos.dart';
import 'emisor_archivo.dart';
import 'puente_ble.dart';
import 'receptor_archivo.dart';
import 'repositorio_historial.dart';

/// Envío en espera de conexión / turno.
class SolicitudEnvio {
  SolicitudEnvio({required this.id, required this.nombre, required this.leer});
  final String id;
  final String nombre;
  final Future<Uint8List> Function() leer;
}

/// Oferta entrante pendiente de que el usuario acepte o rechace.
class OfertaEntrante {
  OfertaEntrante(this.meta, this.emisor);
  final MetadatosArchivo meta;
  final String emisor;
  final Completer<bool> _respuesta = Completer<bool>();
}

enum RolTransferencia { ninguno, receptor, emisor }

/// Orquesta los roles de la transferencia por BLE y el historial.
class EstadoTransferencias extends ChangeNotifier {
  EstadoTransferencias({
    required this.repositorio,
    required this.directorioRecibidos,
    required this.directorioTmp,
    required this.ajustes,
    PuenteBle? puente,
    this.nombreLocal = 'Archivos IPN',
    this.tiempoRespuesta = const Duration(seconds: 90),
    this.tiempoBloque = const Duration(seconds: 15),
  }) : puente = puente ?? PuenteBleReal();

  static const String textoPolitica =
      'Si se pierde la conexión, la transferencia se marca como fallida y '
      'debe reenviarse desde el inicio.';

  final RepositorioHistorial repositorio;
  final Directory directorioRecibidos;
  final Directory directorioTmp;
  final AjustesApp ajustes;
  final PuenteBle puente;
  final String nombreLocal;
  final Duration tiempoRespuesta;
  final Duration tiempoBloque;

  HistorialTransferencias _historial = HistorialTransferencias();
  final ColaTransferencias<SolicitudEnvio> _cola = ColaTransferencias<SolicitudEnvio>();

  EstadoBluetooth estadoBt = EstadoBluetooth.desconocido;
  RolTransferencia rol = RolTransferencia.ninguno;

  // Receptor.
  bool recibiendo = false;
  String? nombreAnuncio;
  OfertaEntrante? ofertaEntrante;
  StreamSubscription<TransporteBytes>? _subConexiones;
  Enlace? _enlaceRx;
  ReceptorArchivo? _receptor;
  bool receptorConectado = false;

  // Emisor.
  List<DispositivoEncontrado> dispositivos = <DispositivoEncontrado>[];
  bool escaneando = false;
  String? mensajeEscaneo;
  DispositivoEncontrado? dispositivoConectado;
  bool conectando = false;
  Enlace? _enlaceTx;
  EmisorArchivo? _emisor;
  bool _procesando = false;
  StreamSubscription<DispositivoEncontrado>? _subEscaneo;
  StreamSubscription<EstadoConexion>? _subEstadoTx;

  /// Aviso local de una sola lectura (la UI lo muestra como SnackBar).
  String? aviso;
  bool _liberado = false;

  List<RegistroTransferencia> get historial =>
      List<RegistroTransferencia>.unmodifiable(_historial.registros);

  List<RegistroTransferencia> get pendientes => _historial.registros
      .where((r) =>
          r.direccion == DireccionTransferencia.enviado &&
          r.estado == EstadoTransferencia.pendiente &&
          _cola.items.any((s) => s.id == r.id))
      .toList()
      .reversed
      .toList();

  RegistroTransferencia? get activa {
    for (final r in _historial.registros) {
      if (r.estado == EstadoTransferencia.enCurso) return r;
    }
    return null;
  }

  bool get emisorConectado => dispositivoConectado != null;

  Future<void> iniciar() async {
    _historial = await repositorio.cargar();
    _notificar();
  }

  void _notificar() {
    if (!_liberado) notifyListeners();
  }

  String? consumirAviso() {
    final a = aviso;
    aviso = null;
    return a;
  }

  void _avisar(String texto) {
    aviso = texto;
    _notificar();
  }

  // ---------------------------------------------------------------- historial

  void _registrar(RegistroTransferencia r) {
    final previo = _historial.registros.where((x) => x.id == r.id).firstOrNull;
    _historial.guardar(r);
    final cambioEstado = previo == null || previo.estado != r.estado;
    if (cambioEstado) {
      unawaited(repositorio.guardar(_historial));
      if (r.estado.esFinal) _avisarFin(r);
    }
    _notificar();
  }

  void _avisarFin(RegistroTransferencia r) {
    final accion = r.direccion == DireccionTransferencia.enviado ? 'Envío' : 'Recepción';
    final detalle = r.motivo == null ? '' : ': ${r.motivo}';
    _avisar('$accion de «${r.nombre}» ${r.estado.etiqueta.toLowerCase()}$detalle');
  }

  Future<void> borrarHistorialFinalizado() async {
    _historial.registros.removeWhere((r) => r.estado.esFinal);
    await repositorio.guardar(_historial);
    _notificar();
  }

  // ----------------------------------------------------------- estado de BT

  Future<void> refrescarEstadoBt(RolBle rolBle) async {
    estadoBt = await puente.estado(rolBle);
    _notificar();
  }

  Future<void> solicitarPermisos(RolBle rolBle) async {
    estadoBt = await puente.solicitar(rolBle);
    _notificar();
  }

  Future<void> abrirAjustesSistema(RolBle rolBle) => puente.abrirAjustes(rolBle);

  // ----------------------------------------------------------------- receptor

  Future<void> iniciarRecepcion() async {
    if (recibiendo) return;
    estadoBt = await puente.solicitar(RolBle.periferico);
    if (!estadoBt.disponible) {
      _notificar();
      return;
    }
    await detenerEmisor();
    _subConexiones ??= puente.conexiones.listen(_alConectarEmisor);
    estadoBt = await puente.iniciarServidor();
    if (!estadoBt.disponible) {
      _notificar();
      return;
    }
    recibiendo = true;
    rol = RolTransferencia.receptor;
    nombreAnuncio = puente.nombreAnuncio;
    _notificar();
  }

  Future<void> detenerRecepcion() async {
    recibiendo = false;
    receptorConectado = false;
    await _cerrarReceptor();
    await puente.detenerServidor();
    if (rol == RolTransferencia.receptor) rol = RolTransferencia.ninguno;
    nombreAnuncio = null;
    _notificar();
  }

  Future<void> _cerrarReceptor() async {
    final r = _receptor;
    final e = _enlaceRx;
    _receptor = null;
    _enlaceRx = null;
    await r?.cerrar();
    try {
      await e?.cerrar();
    } catch (_) {}
  }

  void _alConectarEmisor(TransporteBytes t) {
    unawaited(_cerrarReceptor());
    final enlace = Enlace(t);
    _enlaceRx = enlace;
    receptorConectado = true;
    _receptor = ReceptorArchivo(
      enlace: enlace,
      directorioRecibidos: directorioRecibidos,
      directorioTmp: directorioTmp,
      decidir: _decidirOferta,
      alCambiar: _registrar,
    );
    enlace.estado.listen((e) {
      if (e == EstadoConexion.desconectado && identical(_enlaceRx, enlace)) {
        receptorConectado = false;
        if (ofertaEntrante != null) responderOferta(false);
        _notificar();
        if (recibiendo) unawaited(_reanunciar());
      }
    });
    _notificar();
  }

  Future<void> _reanunciar() async {
    try {
      await puente.detenerServidor();
      await puente.iniciarServidor();
    } catch (_) {}
  }

  Future<bool> _decidirOferta(MetadatosArchivo meta, String emisor) {
    final o = OfertaEntrante(meta, emisor);
    ofertaEntrante = o;
    _notificar();
    return o._respuesta.future;
  }

  /// El usuario acepta o rechaza explícitamente la oferta mostrada.
  void responderOferta(bool acepta) {
    final o = ofertaEntrante;
    if (o == null) return;
    ofertaEntrante = null;
    if (!o._respuesta.isCompleted) o._respuesta.complete(acepta);
    _notificar();
  }

  // ------------------------------------------------------------------- emisor

  Future<void> escanear() async {
    if (escaneando) return;
    estadoBt = await puente.solicitar(RolBle.central);
    if (!estadoBt.disponible) {
      _notificar();
      return;
    }
    if (recibiendo) await detenerRecepcion();
    rol = RolTransferencia.emisor;
    dispositivos = <DispositivoEncontrado>[];
    escaneando = true;
    mensajeEscaneo = null;
    _notificar();
    await _subEscaneo?.cancel();
    _subEscaneo = puente.escanear().listen(
      (d) {
        if (dispositivos.every((x) => x.id != d.id)) {
          dispositivos = [...dispositivos, d];
          _notificar();
        }
      },
      onDone: () {
        escaneando = false;
        if (dispositivos.isEmpty) {
          mensajeEscaneo = puente.errorCliente ??
              'No se encontraron receptores. En el otro teléfono abre Compartir → Recibir.';
        }
        _notificar();
      },
      onError: (Object _) {
        escaneando = false;
        _notificar();
      },
    );
  }

  Future<void> detenerEscaneo() async {
    await _subEscaneo?.cancel();
    _subEscaneo = null;
    escaneando = false;
    _notificar();
  }

  Future<bool> conectarCon(DispositivoEncontrado d) async {
    if (conectando) return false;
    await detenerEscaneo();
    conectando = true;
    _notificar();
    final t = await puente.conectar(d.id);
    conectando = false;
    if (t == null) {
      mensajeEscaneo = puente.errorCliente ?? 'No se pudo conectar con ${d.nombre}.';
      _notificar();
      return false;
    }
    final enlace = Enlace(t);
    _enlaceTx = enlace;
    dispositivoConectado = d;
    _subEstadoTx = enlace.estado.listen((e) {
      if (e == EstadoConexion.desconectado && identical(_enlaceTx, enlace)) {
        dispositivoConectado = null;
        _enlaceTx = null;
        _avisar('Conexión con ${d.nombre} perdida.');
      }
    });
    _notificar();
    return true;
  }

  Future<void> detenerEmisor() async {
    await detenerEscaneo();
    await _subEstadoTx?.cancel();
    _subEstadoTx = null;
    dispositivoConectado = null;
    final e = _enlaceTx;
    _enlaceTx = null;
    try {
      await e?.cerrar();
    } catch (_) {}
    await puente.desconectar();
    if (rol == RolTransferencia.emisor) rol = RolTransferencia.ninguno;
    _notificar();
  }

  /// Agrega un archivo a la cola. Devuelve un mensaje de error o `null`.
  String? encolarEnvio(EntradaArchivo entrada, ServicioArchivos servicio) {
    final motivo = ValidadorTransferencia.motivoNoEnviable(entrada.nombre, entrada.tamano);
    if (motivo != null) return motivo;
    final nombre = ValidadorTransferencia.sanear(entrada.nombre);
    return encolarBytes(nombre, entrada.tamano ?? 0,
        () => servicio.leer(entrada, maxBytes: ValidadorTransferencia.maxBytes));
  }

  String? encolarBytes(String nombre, int longitud, Future<Uint8List> Function() leer) {
    final id = Sobre.nuevaSesion();
    final err = _cola.encolar(SolicitudEnvio(id: id, nombre: nombre, leer: leer));
    if (err != null) {
      _avisar(err);
      return err;
    }
    _registrar(RegistroTransferencia.nuevo(
      id: id,
      direccion: DireccionTransferencia.enviado,
      nombre: nombre,
      tipo: ValidadorTransferencia.tipoDeNombre(nombre) ?? '',
      longitud: longitud,
      dispositivo: dispositivoConectado?.nombre,
    ));
    return null;
  }

  /// Procesa la cola en orden mientras haya conexión. Llamar tras la
  /// confirmación explícita del usuario.
  Future<void> iniciarCola() async {
    if (_procesando) return;
    _procesando = true;
    try {
      while (!_cola.vacia && _enlaceTx != null) {
        final s = _cola.siguiente()!;
        await _enviarUno(s);
      }
    } finally {
      _procesando = false;
      _notificar();
    }
  }

  Future<void> _enviarUno(SolicitudEnvio s) async {
    final enlace = _enlaceTx;
    if (enlace == null) return;
    final emisor = EmisorArchivo(
      enlace: enlace,
      nombreLocal: nombreLocal,
      alterarBloque: ajustes.alterarBloque,
      alterarNombre: ajustes.alterarNombre,
      tiempoRespuesta: tiempoRespuesta,
      tiempoBloque: tiempoBloque,
      alCambiar: _registrar,
    );
    _emisor = emisor;
    await emisor.enviar(
      id: s.id,
      nombre: s.nombre,
      leer: s.leer,
      dispositivo: dispositivoConectado?.nombre,
    );
    _emisor = null;
  }

  /// Cancela un envío pendiente (aún no iniciado).
  void cancelarPendiente(String id) {
    if (!_cola.quitar((s) => s.id == id)) return;
    final r = _historial.registros.where((x) => x.id == id).firstOrNull;
    if (r != null && r.estado == EstadoTransferencia.pendiente) {
      _registrar(r.conEstado(EstadoTransferencia.cancelado, motivo: 'cancelado antes de enviar'));
    }
  }

  /// Cancela la transferencia en curso (envío o recepción).
  Future<void> cancelarActiva() async {
    _emisor?.cancelar();
    await _receptor?.cancelar();
  }

  @override
  void dispose() {
    _liberado = true;
    responderOferta(false);
    unawaited(_subEscaneo?.cancel());
    unawaited(_subConexiones?.cancel());
    unawaited(_subEstadoTx?.cancel());
    unawaited(_cerrarReceptor());
    unawaited(_enlaceTx?.cerrar());
    super.dispose();
  }
}
