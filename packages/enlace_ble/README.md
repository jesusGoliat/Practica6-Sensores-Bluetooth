# enlace_ble

Protocolo de enlace (Dart puro, probado con pruebas unitarias) y transporte
BLE (`bluetooth_low_energy` 6.2.1) de la Práctica 6. Contrato: `docs/diseno-p6.md`.

## GATT

| Elemento | UUID | Propiedades | Sentido |
|---|---|---|---|
| Servicio | `6f1c0001-9b5a-4c1e-8f7e-0c0ffee00006` | primario | |
| RX | `6f1c0002-9b5a-4c1e-8f7e-0c0ffee00006` | write, write without response | central → periférico |
| TX | `6f1c0003-9b5a-4c1e-8f7e-0c0ffee00006` | notify | periférico → central |

Anuncio: nombre local `P6-<app>-<4 hex>` y el UUID del servicio.

## Roles

* **Periférico** (`ServidorBle`): anfitrión/receptor. Publica el servicio, anuncia,
  acepta al primer central que se suscribe a TX, deja de anunciar y expone un
  `TransporteBytes`.
* **Central** (`ClienteBle`): invitado/emisor. `escanear()` filtra por el UUID del
  servicio, `conectar(id)` conecta, negocia MTU, descubre GATT y activa notify en TX.

Ninguno lanza excepciones: los fallos quedan en `estadoActual` y `mensajeError`.

## MTU

No hay tamaño universal. El central pide `requestMTU(512)` (solo Android) y usa
`getMaximumWriteLength(withoutResponse)`; el periférico usa
`getMaximumNotifyLength(central)` y se actualiza con `mtuChanged`. Ese valor es
`TransporteBytes.maxFragmento` (cabecera incluida); carga útil = valor − 5.
Si no se puede leer o es ≤ 5, se usa 20 (MTU 23 − 3). Tope: 512.

## Fragmentación (capa 1)

`[flags:1][msgId:2 BE][indice:2 BE][carga…]`, `flags` bit 0 = último fragmento.
`msgId` cuenta de 0 a 65535 y vuelve a 0. El `Reensamblador` exige índices
consecutivos desde 0, ignora duplicados, rechaza fragmentos fuera de orden,
descarta incompletos tras 10 s (reloj inyectable) y limita el mensaje a 64 KiB.

## Sobre (capa 2, JSON UTF-8)

```json
{"v":1,"canal":"juego","sesion":"a1b2c3d4","seq":17,"tipo":"JUGADA","ack":null,"datos":{}}
```

| Campo | Significado |
|---|---|
| `v` | versión (1); otra ⇒ `ErrorProtocolo(version)` y se responde `ERROR{codigo:"version"}` |
| `canal` | `juego`, `archivos`, `web`, `control` |
| `sesion` | 8 hexadecimales |
| `seq` | creciente por emisor y sesión (automático en `Enlace.enviar`) |
| `tipo` | tipo de mensaje |
| `ack` | en `ACK`, el `seq` confirmado |
| `datos` | objeto JSON |

Todo mensaje salvo `ACK` y `PING` es confiable: se espera ACK (3 s, 3 reintentos) y
si no llega se lanza `ErrorEnlace`. El receptor responde ACK también a los
duplicados, pero `ControlDuplicados` (últimos 256 `seq` por sesión) evita reaplicarlos.

## Tipos por canal

* Comunes (`control` y cualquiera): `HOLA`, `ACEPTA`, `RECHAZA`, `ACK`, `PING`, `ADIOS`, `ERROR`.
* `juego`: `PARTIDA_NUEVA`, `JUGADA`, `ESTADO`, `REANUDAR`, `FIN`.
* `archivos`: `OFERTA`, `OFERTA_ACEPTA`, `OFERTA_RECHAZA`, `BLOQUE`, `BLOQUE_ACK`, `CANCELA`, `FIN_ARCHIVO`, `RESULTADO`.
* `web`: `PETICION`, `RESPUESTA`, `ERROR_WEB`.

## Permisos

Se piden en el momento de uso (`PermisosBle.solicitar(rol)`), con el `authorize()`
del plugin y `permission_handler` para distinguir la denegación permanente.

| Plataforma | Central (escanear/conectar) | Periférico (anunciar) |
|---|---|---|
| Android 12+ (SDK ≥ 31) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` | `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` |
| Android ≤ 11 (SDK ≤ 30) | Ubicación solo en uso (`ACCESS_FINE/COARSE_LOCATION`) | El plugin también exige ubicación en uso (limitación del plugin) |
| iOS 15+ | Autorización de CoreBluetooth (estado `unauthorized` ⇒ ir a Ajustes) | igual |

Nunca se solicita ubicación en segundo plano. `AndroidManifest.xml` de la app debe
declarar esos permisos (`BLUETOOTH_SCAN` con `neverForLocation` si no se deriva
ubicación, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, y `BLUETOOTH`/`BLUETOOTH_ADMIN`/
ubicación con `maxSdkVersion="30"`).

iOS, `Info.plist`: `NSBluetoothAlwaysUsageDescription` (texto en español explicando
el uso para transferir archivos y jugar).

Estados: `EstadoBluetooth` = `noSoportado`, `apagado`, `sinPermiso`,
`permisoDenegadoPermanente`, `encendido`, `desconocido` (cada uno con `.mensaje`).

## Seguridad

SHA-256 y los ACK detectan alteraciones y pérdidas, **no autentican** ni cifran. El
paquete no implementa criptografía propia: la confidencialidad depende del
emparejamiento/cifrado del enlace del sistema cuando existe. Cualquier dispositivo
cercano puede conectarse al anfitrión (acepta solo a uno a la vez); la aplicación debe
pedir confirmación al usuario (`HOLA`/`ACEPTA`).
