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
