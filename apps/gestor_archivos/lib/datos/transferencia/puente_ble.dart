import 'dart:async';

import 'package:enlace_ble/enlace_ble.dart';

/// Fachada mínima del BLE para poder sustituirla en pruebas.
abstract interface class PuenteBle {
  Future<EstadoBluetooth> estado(RolBle rol);
  Future<EstadoBluetooth> solicitar(RolBle rol);
  Future<void> abrirAjustes(RolBle rol);

  // Receptor (periférico).
  String? get nombreAnuncio;
  Stream<TransporteBytes> get conexiones;
  Future<EstadoBluetooth> iniciarServidor();
  Future<void> detenerServidor();
  String? get errorServidor;

  // Emisor (central).
  Stream<DispositivoEncontrado> escanear();
  Future<TransporteBytes?> conectar(String id);
  Future<void> desconectar();
  String? get errorCliente;
}

class PuenteBleReal implements PuenteBle {
  ServidorBle? _servidor;
  ClienteBle? _cliente;
  final _conexiones = StreamController<TransporteBytes>.broadcast();
  StreamSubscription<TransporteBytes>? _subConexiones;

  ServidorBle get _s => _servidor ??= ServidorBle(app: 'archivos');
  ClienteBle get _c => _cliente ??= ClienteBle();

  @override
  Future<EstadoBluetooth> estado(RolBle rol) => PermisosBle.estado(rol);
  @override
  Future<EstadoBluetooth> solicitar(RolBle rol) => PermisosBle.solicitar(rol);
  @override
  Future<void> abrirAjustes(RolBle rol) => PermisosBle.abrirAjustes(rol);

  @override
  String? get nombreAnuncio => _servidor?.nombreAnuncio;
  @override
  Stream<TransporteBytes> get conexiones => _conexiones.stream;

  @override
  Future<EstadoBluetooth> iniciarServidor() async {
    final s = _s;
    _subConexiones ??= s.conexiones.listen(_conexiones.add);
    return s.iniciar();
  }

  @override
  Future<void> detenerServidor() async => _servidor?.detener();
  @override
  String? get errorServidor => _servidor?.mensajeError;

  @override
  Stream<DispositivoEncontrado> escanear() => _c.escanear(app: 'archivos');
  @override
  Future<TransporteBytes?> conectar(String id) => _c.conectar(id);
  @override
  Future<void> desconectar() async => _cliente?.desconectar();
  @override
  String? get errorCliente => _cliente?.mensajeError;
}
