import 'package:enlace_ble/enlace_ble.dart';

/// Capa inyectable entre el estado de la partida y el transporte BLE.
/// En pruebas se sustituye por una implementación en memoria.
abstract interface class PuenteBle {
  /// Pide permisos y empieza a anunciar. Devuelve el estado de Bluetooth.
  Future<EstadoBluetooth> iniciarAnuncio();
  bool get anunciando;
  String? get mensajeError;
  String? get nombreAnuncio;
  Stream<TransporteBytes> get conexiones;
  Future<void> detenerAnuncio();

  /// Pide permisos del rol central.
  Future<EstadoBluetooth> permisosInvitado();
  Stream<DispositivoEncontrado> escanear();
  Future<TransporteBytes?> conectar(String id);
  String? get mensajeErrorCliente;

  Future<void> abrirAjustes();
  Future<void> liberar();
}

/// Implementación real con [ServidorBle] y [ClienteBle].
class PuenteBleReal implements PuenteBle {
  final ServidorBle _servidor = ServidorBle(app: 'juego');
  final ClienteBle _cliente = ClienteBle();

  @override
  Future<EstadoBluetooth> iniciarAnuncio() => _servidor.iniciar();

  @override
  bool get anunciando =>
      _servidor.estadoActual == EstadoServidor.anunciando ||
      _servidor.estadoActual == EstadoServidor.conectado;

  @override
  String? get mensajeError => _servidor.mensajeError;

  @override
  String? get nombreAnuncio => _servidor.nombreAnuncio;

  @override
  Stream<TransporteBytes> get conexiones => _servidor.conexiones;

  @override
  Future<void> detenerAnuncio() => _servidor.detener();

  @override
  Future<EstadoBluetooth> permisosInvitado() => PermisosBle.solicitar(RolBle.central);

  @override
  Stream<DispositivoEncontrado> escanear() => _cliente.escanear(app: 'juego');

  @override
  Future<TransporteBytes?> conectar(String id) => _cliente.conectar(id);

  @override
  String? get mensajeErrorCliente => _cliente.mensajeError;

  @override
  Future<void> abrirAjustes() => PermisosBle.abrirAjustes();

  @override
  Future<void> liberar() async {
    await _servidor.dispose();
    await _cliente.dispose();
  }
}
