/// Controlador de la consulta web: rol, Bluetooth, conexión y consultas.
library;

import 'dart:async';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/foundation.dart';

import '../cliente/cliente_consulta.dart';
import '../dominio/almacen.dart';
import '../dominio/cache_web.dart';
import '../dominio/favoritos.dart';
import '../dominio/historial_navegacion.dart';
import '../servidor/servidor_consulta.dart';
import 'puente_ble.dart';

/// Rol elegido.
enum RolConsulta { ninguno, servidor, cliente }

/// Fase de la conexión.
enum FaseConsulta {
  sinRol,
  iniciando,
  bluetoothNoDisponible,
  anunciando,
  buscando,
  listaDispositivos,
  conectando,
  conectado,
  desconectado,
}

/// Estado observable de la pantalla.
class EstadoConsultaWeb extends ChangeNotifier {
  /// Crea el controlador. Todo es inyectable para pruebas.
  EstadoConsultaWeb({
    PuenteBle? puente,
    AlmacenTexto? almacen,
    ServidorConsulta Function()? crearServidor,
    Duration tiempoEspera = const Duration(seconds: 20),
  })  : puente = puente ?? PuenteBleReal(),
        cache = CacheWeb(almacen: almacen),
        favoritos = Favoritos(almacen: almacen),
        historial = HistorialNavegacion(),
        _crearServidor = crearServidor ?? ServidorConsulta.new {
    cliente = ClienteConsulta(cache: cache, tiempoEspera: tiempoEspera);
    cache.addListener(notifyListeners);
    favoritos.addListener(notifyListeners);
    historial.addListener(notifyListeners);
    unawaited(Future.wait([cache.cargar(), favoritos.cargar()]));
  }

  final PuenteBle puente;
  final CacheWeb cache;
  final Favoritos favoritos;
  final HistorialNavegacion historial;
  late ClienteConsulta cliente;
  final ServidorConsulta Function() _crearServidor;

  RolConsulta rol = RolConsulta.ninguno;
  FaseConsulta fase = FaseConsulta.sinRol;
  EstadoBluetooth estadoBluetooth = EstadoBluetooth.desconocido;
  String? mensaje;
  ServidorConsulta? servidor;
  final List<DispositivoEncontrado> dispositivos = [];
  String? ultimoDispositivo;
  String? nombreDispositivo;
  Resultado? resultado;
  bool consultando = false;
  bool _liberado = false;

  Enlace? _enlace;
  StreamSubscription<TransporteBytes>? _subConexiones;
  StreamSubscription<EstadoConexion>? _subEstado;
  StreamSubscription<DispositivoEncontrado>? _subEscaneo;

  /// El permiso fue denegado de forma permanente (ofrecer ajustes).
  bool get pidePermisoEnAjustes =>
      estadoBluetooth == EstadoBluetooth.permisoDenegadoPermanente;

  void _avisar() {
    if (!_liberado) notifyListeners();
  }

  /// Elige el rol y arranca.
  Future<void> elegirRol(RolConsulta r) async {
    await _detener();
    rol = r;
    resultado = null;
    mensaje = null;
    if (r == RolConsulta.servidor) {
      servidor ??= _crearServidor();
      servidor!.addListener(_avisar);
      await _iniciarServidor();
    } else if (r == RolConsulta.cliente) {
      await buscar();
    } else {
      fase = FaseConsulta.sinRol;
      _avisar();
    }
  }

  /// Vuelve a la elección de rol.
  Future<void> cambiarRol() => elegirRol(RolConsulta.ninguno);

  Future<void> _iniciarServidor() async {
    fase = FaseConsulta.iniciando;
    _avisar();
    final bt = await puente.iniciarServidor();
    if (_liberado || rol != RolConsulta.servidor) return;
    estadoBluetooth = bt;
    if (!bt.disponible) {
      fase = FaseConsulta.bluetoothNoDisponible;
      mensaje = puente.mensajeError ?? bt.mensaje;
      _avisar();
      return;
    }
    mensaje = null;
    fase = FaseConsulta.anunciando;
    _subConexiones ??= puente.conexionesServidor.listen(_alConectarCliente);
    _avisar();
  }

  void _alConectarCliente(TransporteBytes t) {
    if (rol != RolConsulta.servidor) return;
    _cerrarEnlace();
    final e = Enlace(t);
    _enlace = e;
    servidor!.vincular(e);
    nombreDispositivo = 'Cliente B';
    fase = FaseConsulta.conectado;
    _subEstado = e.estado.listen((s) {
      if (s == EstadoConexion.desconectado) _alPerderEnlace();
    });
    _avisar();
  }

  void _alPerderEnlace() {
    if (_liberado) return;
    _cerrarEnlace();
    servidor?.soltar();
    cliente.conectar(null);
    fase = FaseConsulta.desconectado;
    mensaje = 'Se perdió la conexión Bluetooth.';
    _avisar();
    if (rol == RolConsulta.servidor) unawaited(_iniciarServidor());
  }

  void _cerrarEnlace() {
    _subEstado?.cancel();
    _subEstado = null;
    final e = _enlace;
    _enlace = null;
    if (e != null) unawaited(e.cerrar());
  }

  /// Cliente: escanea servidores A.
  Future<void> buscar() async {
    await _subEscaneo?.cancel();
    _subEscaneo = null;
    fase = FaseConsulta.iniciando;
    mensaje = null;
    dispositivos.clear();
    _avisar();
    final bt = await puente.prepararCliente();
    if (_liberado || rol != RolConsulta.cliente) return;
    estadoBluetooth = bt;
    if (!bt.disponible) {
      fase = FaseConsulta.bluetoothNoDisponible;
      mensaje = bt.mensaje;
      _avisar();
      return;
    }
    fase = FaseConsulta.buscando;
    _avisar();
    _subEscaneo = puente.escanear().listen((d) {
      dispositivos.add(d);
      _avisar();
    }, onDone: () {
      if (fase == FaseConsulta.buscando) {
        fase = FaseConsulta.listaDispositivos;
        if (dispositivos.isEmpty) {
          mensaje = puente.mensajeError ?? 'No se encontró ningún servidor A cerca.';
        }
        _avisar();
      }
    });
  }

  /// Cliente: conecta con [d].
  Future<void> conectar(DispositivoEncontrado d) => _conectarId(d.id, d.nombre);

  Future<void> _conectarId(String id, String nombre) async {
    await _subEscaneo?.cancel();
    _subEscaneo = null;
    fase = FaseConsulta.conectando;
    mensaje = null;
    _avisar();
    final t = await puente.conectar(id);
    if (_liberado || rol != RolConsulta.cliente) return;
    if (t == null) {
      fase = FaseConsulta.desconectado;
      mensaje = puente.mensajeError ?? 'No se pudo conectar.';
      _avisar();
      return;
    }
    ultimoDispositivo = id;
    nombreDispositivo = nombre;
    _cerrarEnlace();
    final e = Enlace(t);
    _enlace = e;
    cliente.conectar(e);
    fase = FaseConsulta.conectado;
    _subEstado = e.estado.listen((s) {
      if (s == EstadoConexion.desconectado) _alPerderEnlace();
    });
    _avisar();
  }

  /// Reintenta: reconecta con el último dispositivo o vuelve a buscar.
  Future<void> reconectar() async {
    if (rol == RolConsulta.servidor) return _iniciarServidor();
    final id = ultimoDispositivo;
    if (id != null) return _conectarId(id, nombreDispositivo ?? id);
    return buscar();
  }

  /// Abre los ajustes de la aplicación.
  Future<void> abrirAjustes() =>
      puente.abrirAjustes(rol == RolConsulta.servidor ? RolBle.periferico : RolBle.central);

  /// Cliente: consulta [url] (red o caché).
  Future<void> consultar(String url, {bool registrarHistorial = true}) async {
    url = url.trim();
    if (url.isEmpty || consultando) return;
    consultando = true;
    _avisar();
    final r = await cliente.consultar(url);
    consultando = false;
    resultado = r;
    if (registrarHistorial) historial.visitar(url);
    _avisar();
  }

  /// Historial: atrás.
  Future<void> atras() async {
    final u = historial.atras();
    if (u != null) await consultar(u, registrarHistorial: false);
  }

  /// Historial: adelante.
  Future<void> adelante() async {
    final u = historial.adelante();
    if (u != null) await consultar(u, registrarHistorial: false);
  }

  /// Muestra una entrada de caché sin usar la red.
  void abrirDeCache(EntradaCache e) {
    resultado = ClienteConsulta.resultadoDeCache(e, aviso: 'Abierta desde la caché local.');
    _avisar();
  }

  Future<void> _detener() async {
    await _subEscaneo?.cancel();
    _subEscaneo = null;
    _cerrarEnlace();
    servidor?.soltar();
    servidor?.removeListener(_avisar);
    cliente.conectar(null);
    try {
      await puente.detenerServidor();
      await puente.desconectar();
    } catch (_) {}
  }

  @override
  void dispose() {
    _liberado = true;
    _subConexiones?.cancel();
    _subEscaneo?.cancel();
    _subEstado?.cancel();
    final e = _enlace;
    if (e != null) unawaited(e.cerrar());
    cliente.dispose();
    servidor?.dispose();
    unawaited(puente.dispose());
    cache.dispose();
    favoritos.dispose();
    historial.dispose();
    super.dispose();
  }
}
