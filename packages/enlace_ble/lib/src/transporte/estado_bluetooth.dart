/// Estado de Bluetooth visto por la aplicación.
library;

/// Situaciones que la UI debe distinguir.
enum EstadoBluetooth {
  noSoportado,
  apagado,
  sinPermiso,
  permisoDenegadoPermanente,
  encendido,
  desconocido;

  /// Mensaje en español para mostrar al usuario.
  String get mensaje => switch (this) {
        EstadoBluetooth.noSoportado =>
          'Este dispositivo no admite Bluetooth de bajo consumo (BLE) en este rol.',
        EstadoBluetooth.apagado =>
          'Bluetooth está apagado. Actívalo desde los ajustes del sistema.',
        EstadoBluetooth.sinPermiso =>
          'Falta el permiso de Bluetooth. Acéptalo para continuar.',
        EstadoBluetooth.permisoDenegadoPermanente =>
          'El permiso de Bluetooth fue denegado. Concédelo en los ajustes de la aplicación.',
        EstadoBluetooth.encendido => 'Bluetooth listo.',
        EstadoBluetooth.desconocido =>
          'No se pudo determinar el estado de Bluetooth. Inténtalo de nuevo.',
      };

  /// `true` solo si se puede usar Bluetooth.
  bool get disponible => this == EstadoBluetooth.encendido;
}

/// Rol BLE de la aplicación.
enum RolBle {
  /// Escanea y conecta (invitado / emisor).
  central,

  /// Anuncia y acepta (anfitrión / receptor).
  periferico,
}
