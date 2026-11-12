# Diseño de la Práctica 6 (contrato para implementación)

> Documento de trabajo interno. Fuente única de verdad para nombres, tipos y
> mensajes. Si algo cambia en el código, se actualiza aquí en el mismo commit.

## Monorepo

```text
packages/comun/        (existente) temas Guinda IPN / Azul ESCOM, textos, resaltado JSON/XML, widgets
packages/sensores/     NUEVO — sensores tras interfaz (acelerómetro y giroscopio)
packages/enlace_ble/   NUEVO — protocolo (puro Dart) + transporte BLE (bluetooth_low_energy 6.2.1)
apps/gestor_archivos/  Archivos IPN — + transferencia BLE, biometría, sacudir, consulta web por BT
apps/juego_pares/      Pares IPN   — + partida por BLE entre 2 dispositivos, control por sensores
```

Versiones: Flutter 3.47.6, Dart 3.13.5, AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, JDK 21,
minSdk 24, targetSdk 36, iOS 15. Plugins nuevos: `sensors_plus ^7.1.1`,
`local_auth ^3.0.2` (solo gestor), `bluetooth_low_energy ^6.2.1`,
`permission_handler ^13.0.2`, `crypto ^3.0.8`. Estado con `provider`.
Español en toda la UI (textos en `comun` o en la app).

## Paquete `sensores`

```dart
enum TipoSensor { acelerometro, giroscopio }      // unidades: 'm/s²' y 'rad/s'
enum OrigenLectura { fisica, simulada }
enum EstadoSensor { inactivo, escuchando, pausado, ausente, sinDatos, error }

class LecturaSensor { TipoSensor tipo; double x, y, z; String unidad;
  DateTime instante; OrigenLectura origen; double get magnitud; }

abstract interface class FuenteSensor {
  TipoSensor get tipo; OrigenLectura get origen;
  Future<bool> disponible();                       // false => sensor ausente
  Stream<LecturaSensor> lecturas(Duration periodo); // cancelar la suscripción la detiene
}
class FuenteSensoresPlus implements FuenteSensor   // física (sensors_plus, samplingPeriod)
class FuenteSimulada implements FuenteSensor       // pruebas/demo; origen = simulada; puede ser "ausente"

class ControladorSensor extends ChangeNotifier {   // uno por sensor
  ControladorSensor(FuenteSensor fuente, {Duration periodo = 100 ms, Duration limiteSinDatos = 2 s});
  EstadoSensor estado; LecturaSensor? ultima; List<EventoBitacora> bitacora; // pausa/reanuda/ausente/etc.
  Future<void> iniciar(); void detener(); void pausar(); void reanudar(); // pausar cancela la suscripción
}
class DetectorSacudida   { bool procesar(LecturaSensor l); }  // acelerómetro, umbral ~ 15 m/s² sin g, enfriamiento 800 ms
class DetectorInclinacion{ Direccion procesar(LecturaSensor l); } // acelerómetro x/y, umbral 3.5 m/s², repetición 350 ms
class DetectorGiro       { bool procesar(LecturaSensor l); }  // giroscopio, |z| o |y| > 4 rad/s, enfriamiento 800 ms
enum Direccion { ninguna, izquierda, derecha, arriba, abajo }

// UI reutilizable
class PanelSensor extends StatelessWidget   // valor x/y/z, unidad, instante, estado, insignia FÍSICA/SIMULADA
class PantallaSensores extends StatefulWidget // ambos sensores + bitácora; pausa/reanuda con AppLifecycle
```

Uso de las lecturas:
- **Juego:** inclinar (acelerómetro) mueve un cursor sobre el tablero; giro rápido de muñeca (giroscopio) voltea la carta del cursor. Se activa con un interruptor «Control por movimiento».
- **Gestor:** sacudir (acelerómetro) refresca el listado de la carpeta actual.
- Las suscripciones se cancelan al salir de la pantalla y al pasar a segundo plano (`AppLifecycleState.paused/inactive/hidden`) y se reanudan al volver.

Biometría (gestor): `local_auth` protege **Eliminar** y la sección **Bóveda** (carpeta privada `protegido/`). `biometricOnly: false` → alternativa PIN/patrón del sistema. Sin hardware o sin enrolamiento: mensaje claro y se permite con credencial del dispositivo si existe; si no hay ningún bloqueo configurado, la acción queda bloqueada con explicación. La biometría no entrega la huella ni cifra archivos.

## Paquete `enlace_ble`

### GATT (documentado)
- Servicio: `6f1c0001-9b5a-4c1e-8f7e-0c0ffee00006`
- Característica RX (central → periférico, *write without response* + *write*): `6f1c0002-9b5a-4c1e-8f7e-0c0ffee00006`
- Característica TX (periférico → central, *notify*): `6f1c0003-9b5a-4c1e-8f7e-0c0ffee00006`
- Anuncio: nombre local `P6-<app>-<4 hex>` y el UUID de servicio.
- Roles: **periférico** = anfitrión/receptor/servidor A (anuncia, acepta); **central** = invitado/emisor/cliente B (escanea, conecta). En el juego cualquiera puede elegir ser anfitrión o invitado.
- MTU: central llama `requestMTU(512)`/lee `maximumWriteLength`; periférico usa `getMaximumNotifyLength(central)`. **No hay tamaño universal**: el fragmento útil = longitud máxima negociada − 5 bytes de cabecera.

### Fragmentación (capa 1)
Cada escritura/notificación = `[flags:1][msgId:2 BE][indice:2 BE][carga…]`; `flags bit0 = último fragmento`.
`Reensamblador` agrupa por `msgId`, exige índices consecutivos desde 0, descarta mensaje incompleto tras 10 s y limita el mensaje total a 64 KiB.

### Sobre (capa 2, JSON UTF‑8)
```json
{"v":1,"canal":"juego|archivos|web|control","sesion":"a1b2c3d4","seq":17,"tipo":"JUGADA","ack":null,"datos":{}}
```
- `v` versión de protocolo (=1). Otra versión ⇒ `ERROR{codigo:"version"}` y se ignora.
- `sesion` id de partida/transferencia/sesión web (8 hex).
- `seq` creciente por emisor y sesión. **ControlDuplicados**: un `seq` ya procesado se ignora (se re‑envía ACK), nunca se re‑aplica.
- `ack` = seq confirmado (en mensajes `ACK`).
- `Enlace`: envía con seq automático, espera `ACK` (timeout 3 s, 3 reintentos) para tipos confiables, emite `Stream<Sobre>` ya deduplicado.

Tipos comunes: `HOLA{app, nombre, version}`, `ACEPTA`, `RECHAZA{motivo}`, `ACK`, `PING`, `ADIOS{motivo}`, `ERROR{codigo, mensaje}`.

Juego (`canal: juego`): `PARTIDA_NUEVA{semilla, nivel, anfitrionEmpieza, idPartida}`, `JUGADA{indice, jugador, turno}`, `ESTADO{snapshot}`, `REANUDAR{idPartida, ultimoSeq}`, `FIN{ganador, puntos}`.
Archivos (`canal: archivos`): `OFERTA{id, nombre, tipo, longitud, sha256, bloque}`, `OFERTA_ACEPTA{id}`, `OFERTA_RECHAZA{id, motivo}`, `BLOQUE{id, n, b64}`, `BLOQUE_ACK{id, n}`, `CANCELA{id, motivo}`, `FIN_ARCHIVO{id}`, `RESULTADO{id, ok, motivo}`.
Web (`canal: web`): `PETICION{req, url}`, `RESPUESTA{req, estado, tipo, cuerpo|b64, bytes, ms, urlFinal, fecha}`, `ERROR_WEB{req, codigo, mensaje}`.

### Transporte
```dart
abstract interface class TransporteBytes {          // una conexión ya establecida
  int get maxFragmento;                              // negociado
  Stream<Uint8List> get recibidos;
  Future<void> enviar(Uint8List fragmento);
  Stream<EstadoConexion> get estado;                 // conectando, conectado, desconectado
  Future<void> cerrar();
}
class TransporteMemoria  // par conectado en memoria para pruebas (con opción de perder/duplicar)
class ServidorBle        // periférico: anuncia, acepta 1 central, expone TransporteBytes
class ClienteBle         // central: escanea (filtra por servicio), conecta, descubre GATT, MTU, expone TransporteBytes
```
Estados de BT a manejar: no soportado, apagado, sin permiso, permiso denegado permanentemente, encendido.

## Reglas de la transferencia
- Tipos permitidos: `txt json xml jpg` (también `.jpeg` → `jpg`). Límite didáctico **512 KiB**. Bloque = 2 KiB de datos (base64 en el sobre), ACK por bloque.
- Nombre lógico saneado: solo `[A-Za-z0-9._ -áéíóúñÁÉÍÓÚÑ]`, sin `/ \ ..`, máx 80 caracteres; la extensión debe coincidir con el tipo. Destino: `recibidos/` dentro del espacio privado; si existe, se agrega ` (2)`.
- Receptor guarda en `tmp/<id>.part` (privado), verifica longitud + SHA‑256 y luego renombra. Falla ⇒ borra el temporal y marca **fallido**.
- Sin reanudación: tras desconexión la transferencia queda **fallida**; reenviar empieza desde el bloque 0.
- Cola acotada: máx 5 pendientes. Estados: `pendiente, enCurso, completado, cancelado, fallido`. Historial persistido en JSON; al arrancar, `enCurso`/`pendiente` huérfanos ⇒ `fallido` (motivo «interrumpida por reinicio»).
- Modo de prueba «Alterar un bloque» (solo en Ajustes → Diagnóstico) para demostrar integridad fallida.
- SHA‑256 detecta alteraciones, no autentica. La sesión BLE no se cifra con criptografía propia: se apoya en el emparejamiento/cifrado del enlace del sistema cuando existe; se documenta.

## Reglas de la consulta web
- A = servidor (Internet), B = cliente (solo BT). Lista blanca de recursos de prueba HTTPS:
  `https://jsonplaceholder.typicode.com/todos/1`, `/posts/1`, `/users/1`,
  `https://httpbin.org/json`, `https://httpbin.org/uuid`, `https://httpbin.org/image/jpeg` (imagen ~35 KB),
  `https://api.github.com/zen`, `https://www.ipn.mx/robots.txt`.
  Dominios permitidos: `jsonplaceholder.typicode.com`, `httpbin.org`, `api.github.com`, `www.ipn.mx`.
- Validar: esquema `https`, host en lista, sin credenciales en URL, puerto 443, no IP literal; resolver DNS y rechazar loopback/privadas/link‑local; redirecciones seguidas manualmente (máx 3) revalidando cada una. Tamaño máx 256 KiB, timeout 10 s, máx 10 peticiones por minuto por sesión.
- Tipos admitidos: `text/plain`, `application/json`, `text/html` (se muestra como texto, sin ejecutar), `image/jpeg|png` (≤ 64 KiB). Otro ⇒ error «formato no admitido».
- Cliente: barra de dirección, rol, estado, tiempo (ms), errores, atrás/adelante (historial local), favoritos, caché con fecha; insignia **RED** o **CACHÉ (fecha)**. `req` único y control de duplicados en ambos extremos.
- Sin Bluetooth: muestra error o la copia de caché marcada como tal.
