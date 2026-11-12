/// Permisos y estado de Bluetooth, pedidos en el momento de uso.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';

import 'estado_bluetooth.dart';

/// Utilidad para comprobar y solicitar permisos BLE según plataforma y rol.
///
/// * Android 12+ (SDK ≥ 31): central → `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT`;
///   periférico → `BLUETOOTH_ADVERTISE` + `BLUETOOTH_CONNECT`.
/// * Android ≤ 11 (SDK ≤ 30): ubicación solo con la app en uso, solo para
///   escanear. (El plugin `bluetooth_low_energy` también la exige en modo
///   periférico en esas versiones; es una limitación del plugin.)
/// * iOS: autorización de CoreBluetooth gestionada por el plugin (estado
///   `unauthorized`); solo se puede cambiar desde Ajustes.
///
/// Nunca se solicita ubicación en segundo plano.
abstract final class PermisosBle {
  static BluetoothLowEnergyManager? _gestor(RolBle rol) {
    try {
      return rol == RolBle.central ? CentralManager() : PeripheralManager();
    } catch (_) {
      return null;
    }
  }

  /// Estado actual sin mostrar diálogos.
  static Future<EstadoBluetooth> estado(RolBle rol) async {
    final g = _gestor(rol);
    if (g == null) return EstadoBluetooth.noSoportado;
    try {
      var e = g.state;
      if (e == BluetoothLowEnergyState.unknown) {
        // Al inicio (sobre todo en iOS) el estado tarda un instante en llegar.
        e = await g.stateChanged
            .map((x) => x.state)
            .firstWhere((x) => x != BluetoothLowEnergyState.unknown)
            .timeout(const Duration(seconds: 2), onTimeout: () => g.state);
      }
      return switch (e) {
        BluetoothLowEnergyState.unsupported => EstadoBluetooth.noSoportado,
        BluetoothLowEnergyState.poweredOff => EstadoBluetooth.apagado,
        BluetoothLowEnergyState.poweredOn => EstadoBluetooth.encendido,
        BluetoothLowEnergyState.unauthorized => EstadoBluetooth.sinPermiso,
        BluetoothLowEnergyState.unknown => EstadoBluetooth.desconocido,
      };
    } catch (_) {
      return EstadoBluetooth.desconocido;
    }
  }

  /// Cambios del estado de Bluetooth (útil para reaccionar a encender/apagar).
  static Stream<EstadoBluetooth> observar(RolBle rol) {
    final g = _gestor(rol);
    if (g == null) return const Stream.empty();
    return g.stateChanged.asyncMap((_) => estado(rol));
  }

  /// Comprueba y, si falta, solicita el permiso en este momento.
  /// Nunca lanza: devuelve el [EstadoBluetooth] resultante.
  static Future<EstadoBluetooth> solicitar(RolBle rol) async {
    var actual = await estado(rol);
    if (actual != EstadoBluetooth.sinPermiso) return actual;
    final g = _gestor(rol);
    if (g == null) return EstadoBluetooth.noSoportado;
    if (Platform.isAndroid) {
      var concedido = false;
      try {
        concedido = await g.authorize();
      } catch (_) {
        concedido = await _solicitarConPermissionHandler(rol);
      }
      if (!concedido) {
        actual = await estado(rol);
        if (actual == EstadoBluetooth.sinPermiso &&
            await _denegadoPermanente(rol)) {
          return EstadoBluetooth.permisoDenegadoPermanente;
        }
        return actual;
      }
      return estado(rol);
    }
    // iOS: el aviso de CoreBluetooth sale solo la primera vez; si sigue
    // `unauthorized` el usuario debe cambiarlo en Ajustes.
    try {
      await g.authorize();
    } catch (_) {
      // No implementado en iOS: se ignora.
    }
    actual = await estado(rol);
    return actual == EstadoBluetooth.sinPermiso
        ? EstadoBluetooth.permisoDenegadoPermanente
        : actual;
  }

  /// Abre los ajustes de la aplicación (para permisos denegados).
  static Future<void> abrirAjustes([RolBle rol = RolBle.central]) async {
    try {
      await _gestor(rol)?.showAppSettings();
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  static List<Permission> _permisosBluetooth(RolBle rol) =>
      rol == RolBle.central
      ? [Permission.bluetoothScan, Permission.bluetoothConnect]
      : [Permission.bluetoothAdvertise, Permission.bluetoothConnect];

  /// Alternativa si `authorize()` no está disponible. En Android ≤ 11 los
  /// permisos `bluetooth*` figuran como concedidos, así que solo entonces se
  /// pide ubicación (únicamente al escanear).
  static Future<bool> _solicitarConPermissionHandler(RolBle rol) async {
    try {
      final bt = _permisosBluetooth(rol);
      final previos = await Future.wait(bt.map((p) => p.status));
      if (previos.any((s) => !s.isGranted)) {
        final r = await bt.request();
        return r.values.every((s) => s.isGranted);
      }
      // Android ≤ 11: ubicación solo en uso (el plugin la exige también en
      // modo periférico).
      return (await Permission.locationWhenInUse.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _denegadoPermanente(RolBle rol) async {
    try {
      final bt = _permisosBluetooth(rol);
      final estados = await Future.wait(bt.map((p) => p.status));
      if (estados.any((s) => !s.isGranted)) {
        return estados.any((s) => s.isPermanentlyDenied);
      }
      return (await Permission.locationWhenInUse.status).isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }
}
