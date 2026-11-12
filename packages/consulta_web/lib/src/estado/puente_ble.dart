/// Puente inyectable hacia la capa BLE (para pruebas sin hardware).
library;

import 'dart:async';

import 'package:enlace_ble/enlace_ble.dart';

/// Operaciones BLE que necesita el controlador.
abstract interface class PuenteBle {
  /// Servidor: pide permisos, publica y anuncia. Devuelve el estado de Bluetooth.
  Future<EstadoBluetooth> iniciarServidor();

  /// Servidor: un transporte por cada cliente aceptado.
  Stream<TransporteBytes> get conexionesServidor;

  /// Nombre anunciado por el servidor.
  String get nombreAnuncio;

  /// Servidor: deja de anunciar y desconecta.
  Future<void> detenerServidor();

  /// Cliente: comprueba y solicita permisos del rol central.
  Future<EstadoBluetooth> prepararCliente();

  /// Cliente: busca servidores A.
  Stream<DispositivoEncontrado> escanear();

  /// Cliente: conecta; `null` si falla (ver [mensajeError]).
  Future<TransporteBytes?> conectar(String id);

  /// Cliente: corta la conexión.
  Future<void> desconectar();

  /// Último error legible.
  String? get mensajeError;

  /// Abre los ajustes de la aplicación.
  Future<void> abrirAjustes(RolBle rol);

  /// Libera recursos.
  Future<void> dispose();
}

/// Implementación real con `ServidorBle(app: 'web')`, `ClienteBle` y `PermisosBle`.
class PuenteBleReal implements PuenteBle {
  ServidorBle? _servidor;
  ClienteBle? _cliente;

  ServidorBle get _s => _servidor ??= ServidorBle(app: 'web');
  ClienteBle get _c => _cliente ??= ClienteBle();

  @override
  Future<EstadoBluetooth> iniciarServidor() => _s.iniciar();

  @override
  Stream<TransporteBytes> get conexionesServidor => _s.conexiones;

  @override
  String get nombreAnuncio => _s.nombreAnuncio;

  @override
  Future<void> detenerServidor() async => _servidor?.detener();

  @override
  Future<EstadoBluetooth> prepararCliente() => PermisosBle.solicitar(RolBle.central);

  @override
  Stream<DispositivoEncontrado> escanear() => _c.escanear(app: 'web');

  @override
  Future<TransporteBytes?> conectar(String id) => _c.conectar(id);

  @override
  Future<void> desconectar() async => _cliente?.desconectar();

  @override
  String? get mensajeError => _cliente?.mensajeError ?? _servidor?.mensajeError;

  @override
  Future<void> abrirAjustes(RolBle rol) => PermisosBle.abrirAjustes(rol);

  @override
  Future<void> dispose() async {
    await _servidor?.dispose();
    await _cliente?.dispose();
  }
}
