/// UUID GATT del contrato.
library;

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

/// UUID (texto) del servicio de la Práctica 6.
const String uuidServicioTexto = '6f1c0001-9b5a-4c1e-8f7e-0c0ffee00006';

/// UUID (texto) de RX: central → periférico (write + write without response).
const String uuidRxTexto = '6f1c0002-9b5a-4c1e-8f7e-0c0ffee00006';

/// UUID (texto) de TX: periférico → central (notify).
const String uuidTxTexto = '6f1c0003-9b5a-4c1e-8f7e-0c0ffee00006';

/// Servicio GATT.
final UUID uuidServicio = UUID.fromString(uuidServicioTexto);

/// Característica RX.
final UUID uuidRx = UUID.fromString(uuidRxTexto);

/// Característica TX.
final UUID uuidTx = UUID.fromString(uuidTxTexto);

/// Fragmento por defecto cuando no se puede leer el MTU (MTU 23 − 3).
const int fragmentoPorDefecto = 20;

/// Tope razonable de un fragmento (MTU 512 − 3 ≈ 509; se limita a 512).
const int fragmentoMaximo = 512;

/// Ajusta una longitud informada por el plugin a un fragmento utilizable.
int ajustarFragmento(int? informado) {
  if (informado == null || informado <= 5) return fragmentoPorDefecto;
  return informado > fragmentoMaximo ? fragmentoMaximo : informado;
}

/// Id de fabricante reservado para pruebas (0xFFFF, Bluetooth SIG).
const int idFabricantePruebas = 0xFFFF;

/// Códigos de app que viajan en los datos de fabricante del anuncio Android.
const Map<String, int> codigosApp = {'juego': 1, 'archivos': 2, 'web': 3};

/// Datos de fabricante `['P','6', app, sufijo hi, sufijo lo]` (5 bytes).
///
/// En Android el nombre local no se anuncia porque el plugin lo implementa
/// renombrando el adaptador Bluetooth de todo el teléfono; además, 3 (flags)
/// + 18 (UUID de 128 bits) + 9 (fabricante) = 30 bytes cabe en los 31 del
/// paquete de anuncio.
List<int> datosFabricante(String app, int sufijo) => [
  0x50,
  0x36,
  codigosApp[app] ?? 0,
  (sufijo >> 8) & 0xFF,
  sufijo & 0xFF,
];

/// Decodifica los datos de fabricante; `null` si no son de la práctica.
({String app, int sufijo})? leerDatosFabricante(int id, List<int> datos) {
  if (id != idFabricantePruebas || datos.length < 5) return null;
  if (datos[0] != 0x50 || datos[1] != 0x36) return null;
  final app = codigosApp.entries
      .firstWhere(
        (e) => e.value == datos[2],
        orElse: () => const MapEntry('app', 0),
      )
      .key;
  return (app: app, sufijo: (datos[3] << 8) | datos[4]);
}

/// Nombre visible `P6-<app>-<4hex>`.
String nombreVisible(String app, int sufijo) =>
    'P6-$app-${sufijo.toRadixString(16).padLeft(4, '0')}';

/// Extrae la app de un nombre `P6-<app>-<4hex>` (anuncios iOS).
String? appDeNombre(String? nombre) {
  final m = RegExp(r'^P6-([A-Za-z0-9]+)-[0-9a-f]{4}$').firstMatch(nombre ?? '');
  return m?.group(1);
}
