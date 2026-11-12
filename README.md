# Práctica 6 — Manejo de sensores del dispositivo móvil

[English version](README.en.md)

## Portada

- **Nombre completo:** Jesús Ángel González Arellano
- **Número de boleta:** 2022630690
- **Grupo:** 7CV4
- **Asignatura:** Desarrollo de aplicaciones móviles nativas
- **Profesor(a):** Gabriel Hurtado Avilés
- **Fecha de entrega:** 12 de noviembre de 2026

---

## Estructura del repositorio

```text
README.md                        Este informe (español)
README.en.md                     English version of this report
apps/gestor_archivos/            App 1 «Archivos IPN»: + transferencia BLE, biometría, sacudir, consulta web
apps/juego_pares/                App 2 «Pares IPN»: + partida por BLE, control por sensores
packages/comun/                  Temas, textos, resaltado y widgets compartidos (de la Práctica 4)
packages/sensores/               Acelerómetro y giroscopio tras interfaz, detectores y panel
packages/enlace_ble/             Protocolo (Dart puro) y transporte BLE central/periférico
packages/consulta_web/           Consulta web por Bluetooth: servidor A, cliente B, validador y caché
packages/selector_carpetas_ios/  Plugin Swift: document picker + security-scoped bookmark (Práctica 4)
docs/                            diseno-p6, protocolo, arquitectura, pruebas, implementacion e imágenes
README for IAS/                  Notas para asistentes de IA y declaración de uso de IA
apk/                             APK release de las dos apps
tools/                           Generación de recursos, capturas y utilidades de evidencia
.github/                         Workflows de CI (Android) y de evidencia
codemagic.yaml                   Workflows de iOS (simulador) en Codemagic
```

---

## Resumen

Se extendieron las dos aplicaciones Flutter de la Práctica 4 para Android 7.0+
(API 24) e iOS 15+ con tres ejercicios:

1. **Sensores e interacción:** acelerómetro y giroscopio con panel en vivo,
   detección de ausencia, pausa/reanudación por ciclo de vida, y biometría para
   acciones sensibles.
2. **Transferencia de archivos y partida por Bluetooth Low Energy (BLE)** entre
   dos dispositivos, con protocolo propio, fragmentación según MTU, ACK,
   control de duplicados y verificación SHA-256.
3. **Consulta web por Bluetooth:** un dispositivo sin Internet (B) obtiene un
   recurso HTTPS de una lista blanca a través de otro con Internet (A).

No se usa Firebase, Wi-Fi directo ni Internet entre los dispositivos.

| App | `applicationId` | Novedades de la Práctica 6 |
|---|---|---|
| **Archivos IPN** | `mx.ipn.escom.p6.gestorarchivos` | Sensores, sacudir para actualizar, biometría (Eliminar y Bóveda), transferencia BLE, consulta web |
| **Pares IPN** | `mx.ipn.escom.p6.juegopares` | Sensores, control por inclinación y giro, partida por BLE entre dos dispositivos |

| Documento | Contenido |
|---|---|
| [`docs/diseno-p6.md`](docs/diseno-p6.md) | Contrato de diseño: nombres, tipos, mensajes y reglas |
| [`docs/protocolo.md`](docs/protocolo.md) | GATT, anuncio, fragmentación, sobre JSON, tipos, errores y diagramas |
| [`docs/arquitectura.md`](docs/arquitectura.md) | Componentes, capas, máquinas de estado, permisos, seguridad y límites |
| [`docs/pruebas.md`](docs/pruebas.md) | Criterios, riesgos y matriz de casos |
| [`docs/implementacion.md`](docs/implementacion.md) | Base de la Práctica 4 (archivos y serialización) |
| [`README for IAS/`](README%20for%20IAS/README.md) | Notas para IA, decisiones, estado, limitaciones y uso de IA |
| [`packages/enlace_ble/README.md`](packages/enlace_ble/README.md) | Detalle del protocolo y transporte |
| [`packages/consulta_web/README.md`](packages/consulta_web/README.md) | Detalle de la consulta web |

---

## Tecnología y versiones

| Herramienta | Versión |
|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 |
| Android Gradle Plugin / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0 |
| JDK | 21 |
| Android `minSdk` / `targetSdk` / `compileSdk` | 24 / 36 / 36 |
| iOS deployment target | 15.0 |
| iOS | Solo simulador en Codemagic (`mac_mini_m2`); sin Bluetooth ni sensores |

Plugins nuevos de esta práctica, con la versión resuelta en los `pubspec.lock`:

| Plugin | Versión resuelta | Uso | Dónde |
|---|---|---|---|
| `sensors_plus` | 7.1.1 | Acelerómetro y giroscopio | `packages/sensores`, ambas apps |
| `local_auth` | 3.0.2 | Biometría / credencial del dispositivo | Solo `gestor_archivos` |
| `bluetooth_low_energy` | 6.2.1 | Roles central y periférico BLE | `packages/enlace_ble`, ambas apps |
| `permission_handler` | 12.0.3 | Permisos y denegación permanente | `packages/enlace_ble`, ambas apps |
| `crypto` | 3.0.8 | SHA-256 | Ambas apps |

`permission_handler` se fija en **12.x** (`^12.0.1`): la 13.x exige `compileSdk`
37, que AGP 9.1 no soporta (recomienda como máximo 36). Las versiones exactas
quedan en cada `pubspec.lock`, que se versiona para reproducir la compilación.

---

## Ejercicio 1 — Sensores e interacción

**Qué se lee.** Acelerómetro (`m/s²`) y giroscopio (`rad/s`) mediante la
interfaz `FuenteSensor` del paquete `sensores`. Hay una implementación física
(`FuenteSensoresPlus`) y una simulada (`FuenteSimulada`), de modo que la lógica
se prueba sin hardware.

**Dónde está en la UI.**

- **Gestor:** menú ⋮ de la pantalla principal → **Sensores**; Ajustes →
  **Sensores** («Sacudir para actualizar») y **Diagnóstico** («Usar sensores
  simulados»).
- **Juego:** Ajustes → **Sensores** (panel en vivo, «Usar valores simulados» y
  «Simular sensor ausente»); en el tablero, el interruptor **Control por
  movimiento**.

El panel muestra x/y/z, unidad, instante de la lectura, estado y una insignia
**FÍSICA** o **SIMULADA**, más una bitácora de pausas, reanudaciones y ausencias.

**Qué hacen las lecturas.**

| App | Gesto | Efecto |
|---|---|---|
| Gestor | Sacudida (magnitud sin gravedad > 15 m/s², enfriamiento 800 ms) | Refresca el listado de la carpeta abierta |
| Juego | Inclinación (acelerómetro, umbral 3.5 m/s², repetición 350 ms) | Mueve un cursor sobre el tablero |
| Juego | Giro rápido de muñeca (giroscopio, \|y\| o \|z\| > 4 rad/s, enfriamiento 800 ms) | Voltea la carta del cursor |

**Frecuencia: 100 ms (≈10 lecturas por segundo por sensor).** Basta para
detectar gestos de decenas de milisegundos y refrescar el panel sin que se vea
a saltos, y evita el consumo de batería y de CPU de las frecuencias más altas
(Android permite hasta 200 Hz sin permiso). Los enfriamientos evitan que un
solo movimiento dispare la acción varias veces.

**Ausencia de sensor.** `FuenteSensor.disponible()` devuelve `false` si el
teléfono no tiene el sensor; el estado pasa a `ausente` con un mensaje legible y
la app no se cierra. Si un sensor deja de emitir más de 2 s, el estado es
`sinDatos` y se recupera al volver a recibir lecturas.

**Pausa y reanudación.** Al pasar a segundo plano
(`AppLifecycleState.paused/inactive/hidden`) y al salir de la pantalla se
cancelan las suscripciones; al volver a `resumed` se reanudan. Cada cambio queda
en la bitácora.

**Simulado vs. físico.** La fuente simulada (escenarios normal, extremo y
ausente) sirve para demostrar casos que el hardware no produce con facilidad y
para el simulador de iOS, que no tiene sensores. La insignia siempre dice cuál
se está usando; no se mezclan lecturas.

**Biometría (solo gestor).** `local_auth` protege **Eliminar** y la **Bóveda**
(carpeta privada `protegido/`). Se usa `biometricOnly: false`, así que si no hay
huella enrolada se ofrece el PIN/patrón del sistema; si el teléfono no tiene
ningún bloqueo de pantalla, la acción queda bloqueada con una explicación. Una
autenticación cancelada o fallida no ejecuta la acción. Límites: la app solo
recibe un sí/no del sistema, nunca la huella; la biometría no cifra los archivos
de la Bóveda y depende de lo que haya enrolado el teléfono de prueba.

---

## Juego por Bluetooth

**Roles.** Cualquiera de los dos dispositivos elige en la pestaña **Bluetooth**
del juego: **Anfitrión** (periférico: anuncia y acepta) o **Unirse** (central:
escanea y se conecta). Los permisos se piden al elegir el rol, no al abrir la app.

**Flujo.**

1. El anfitrión anuncia y el invitado escanea y elige la partida de la lista.
2. El invitado envía `HOLA`; el anfitrión ve «¿Aceptar a …?» y responde
   `ACEPTA` o `RECHAZA`.
3. El anfitrión envía `PARTIDA_NUEVA{semilla, nivel, anfitrionEmpieza,
   idPartida}`; ambos construyen el mismo tablero con la misma semilla.
4. Por turnos se envía `JUGADA{indice, jugador, turno}`. El receptor valida que
   sea el turno de quien juega, que el contador coincida y que el índice esté en
   rango y la carta libre; si no, responde `ERROR{turno|jugada}` y el estado no
   cambia.
5. `FIN{ganador, puntos}` cierra la partida; ambos muestran el mismo resultado.

**Mensajes:** `HOLA`, `ACEPTA`, `RECHAZA`, `ACK`, `PING`, `ADIOS`, `ERROR`,
`PARTIDA_NUEVA`, `JUGADA`, `ESTADO`, `REANUDAR`, `FIN` (ver
[`docs/protocolo.md`](docs/protocolo.md)).

**Control de duplicados.** Cada emisor numera `seq` por sesión; un `seq` ya
procesado se ignora (se reenvía el `ACK`) y nunca se reaplica. El emisor espera
`ACK` 3 s y reintenta 3 veces. En Diagnóstico hay acciones para reenviar la
última jugada, jugar fuera de turno, enviar una jugada inválida y enviar
`v:2`, con las que se demuestran esos rechazos.

**Reconexión y persistencia.** Si se pierde el enlace, ambos muestran
«Conexión perdida» y **Reintentar conexión**; al reconectar se usa
`REANUDAR{idPartida, ultimoSeq}` para retomar el mismo tablero y turno. El
estado de la partida en red se persiste: tras cerrar la app aparece
**Recuperar partida** o el aviso de que terminó con su motivo.

---

## Compatibilidad del transporte

**BLE GATT.** Un servicio propio (`6f1c0001-9b5a-4c1e-8f7e-0c0ffee00006`) con
una característica RX (central → periférico, write / write without response) y
una TX (periférico → central, notify). La especificación completa, la cabecera
de fragmento, el sobre JSON y los códigos de error están en
[`docs/protocolo.md`](docs/protocolo.md).

**Fragmentación según MTU.** No existe un tamaño universal. El central solicita
MTU 512 (Android) y lee la longitud máxima de escritura; el periférico usa la
longitud máxima de notificación del central. El fragmento útil es la longitud
negociada menos 5 bytes de cabecera; si no se puede leer, se usan 20 bytes
(MTU 23 − 3). El reensamblador descarta mensajes incompletos a los 10 s y limita
cada mensaje a 64 KiB.

**Anuncio: Android sin nombre local.** En Android, el plugin implementa el
nombre local con `BluetoothAdapter.setName()`, que renombraría todo el teléfono,
y además no cabe junto al UUID de 128 bits en los 31 bytes del anuncio. Por eso
el anfitrión Android anuncia el UUID de servicio y **datos de fabricante** (id
`0xFFFF`: bytes `'P'`, `'6'`, código de app 1 juego / 2 archivos / 3 web y un
sufijo de 2 bytes). El central reconstruye el nombre `P6-<app>-<4 hex>`. En iOS
sí se anuncia el nombre local con ese formato.

**RFCOMM no implementado.** RFCOMM (Bluetooth clásico) no existe en iOS; se
eligió BLE, que en teoría permite interoperar con iOS. No se afirma
compatibilidad con RFCOMM.

**Matriz de pares y transportes.**

| Par | Transporte | Estado |
|---|---|---|
| Android ↔ Android | BLE GATT | `pendiente de evidencia` (se completa con la sesión en dispositivos) |
| Android ↔ iOS | BLE GATT | No verificado (sin iPhone) |
| iOS ↔ iOS | BLE GATT | No verificado (sin iPhone) |
| Cualquiera | RFCOMM | No implementado |

El código usa APIs multiplataforma, pero no se afirma compatibilidad con iOS: el
simulador de iOS no tiene Bluetooth.

---

## Ejercicio 2 — Transferencia de archivos

En el gestor, la pestaña **Compartir**: un teléfono activa **Recibir archivos**
(periférico, se anuncia como `P6-archivos-…`) y el otro (central) busca,
conecta y envía el archivo elegido desde el explorador (menú ⋮).

- **Tipos y límites:** `txt`, `json`, `xml`, `jpg` (`.jpeg` se normaliza);
  máximo **512 KiB**; bloques de 2 KiB (base64 en el sobre) con `BLOQUE_ACK`
  por bloque; cola de hasta 5 envíos.
- **Aceptación explícita:** el receptor ve la oferta (`OFERTA`) y decide; puede
  rechazar (`OFERTA_RECHAZA`) o cancelar en cualquier momento.
- **Validación del nombre:** solo `[A-Za-z0-9._ -áéíóúñÁÉÍÓÚÑ]`, sin `/`, `\` ni
  `..`, máximo 80 caracteres, extensión coherente con el tipo. Destino:
  `recibidos/` del espacio privado; si existe, se agrega ` (2)`.
- **Integridad:** el receptor escribe en `tmp/<id>.part`, verifica longitud y
  **SHA-256** y solo entonces renombra. Si falla, borra el temporal y marca
  `fallido`. SHA-256 detecta alteración o corrupción; **no autentica**.
- **Estados:** `pendiente`, `enCurso`, `completado`, `cancelado`, `fallido`,
  con historial persistido; al reiniciar, los pendientes o en curso huérfanos
  pasan a `fallido` («interrumpida por reinicio»). No hay reanudación: reenviar
  empieza en el bloque 0.
- **Diagnóstico** (Ajustes): «Alterar un bloque» y «Enviar nombre inválido»
  para demostrar el rechazo por integridad y por validación.

---

## Permisos y ciclo de vida

Permisos declarados en los `AndroidManifest.xml` de `src/main` y claves de
`Info.plist`:

| Permiso / clave | Android 12+ (API 31+) | Android ≤ 11 (API ≤ 30) | Rol | Apps |
|---|---|---|---|---|
| `BLUETOOTH_SCAN` (`neverForLocation`) | Sí | — | Central: escanear | Ambas |
| `BLUETOOTH_CONNECT` | Sí | — | Central y periférico | Ambas |
| `BLUETOOTH_ADVERTISE` | Sí | — | Periférico: anunciar | Ambas |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (`maxSdkVersion=30`) | — | Sí | Ambos | Ambas |
| `ACCESS_FINE_LOCATION` (`maxSdkVersion=30`) | — | Sí (exigida para escanear y por el plugin) | Ambos | Ambas |
| `USE_BIOMETRIC` | Sí | Sí | Biometría | Solo gestor |
| `INTERNET` | Sí | Sí | Solo el dispositivo A de la consulta web | Solo gestor |
| `uses-feature` BLE, acelerómetro, giroscopio (`required=false`) | Sí | Sí | La app instala aunque falte el hardware | Ambas |
| `NSBluetoothAlwaysUsageDescription` (iOS) | — | — | Bluetooth | Ambas |
| `NSFaceIDUsageDescription` (iOS) | — | — | Face ID | Solo gestor |

- No hay cadena de uso de movimiento en `Info.plist`: los sensores no requieren
  permiso en Android (muestreo ≤ 200 Hz) y el simulador de iOS no los tiene.
- No se declara `POST_NOTIFICATIONS`. Los avisos son **locales y dentro de la
  app** (por ejemplo, fin de una transferencia con la app abierta o recién
  minimizada); no se usa FCM ni Firebase.
- **Solo primer plano:** no hay servicios en segundo plano. Al minimizar se
  cancelan las suscripciones de sensores y una sesión BLE puede perderse; al
  volver se informa y se ofrece reconectar (juego) o se marca `fallido`
  (archivos).
- Los permisos se piden en contexto, con explicación previa y manejo de
  denegado, denegado permanentemente (botón a Ajustes de la app) y revocado.
- No se pide ubicación en Android 12+ ni en segundo plano, ni almacenamiento amplio.

---

## Ejercicio 3 — Consulta web por Bluetooth

**Roles.** **A (servidor)** tiene Internet, se anuncia como `P6-web-…`, recibe
`PETICION{req, url}`, valida y hace la petición HTTPS. **B (cliente)** no usa
Wi-Fi ni datos, solo Bluetooth, y **nunca hace HTTP**.

**Lista blanca** (puerto 443, HTTPS):

| Dominio | Recursos de prueba |
|---|---|
| `jsonplaceholder.typicode.com` | `/todos/1`, `/posts/1`, `/users/1` |
| `httpbin.org` | `/json`, `/uuid`, `/image/jpeg` (≈35 KB) |
| `api.github.com` | `/zen` |
| `www.ipn.mx` | `/robots.txt` |

**Validaciones en A (en cada salto):** esquema `https`; sin credenciales en la
URL; host que no sea IP literal; host en la lista; puerto 443; resolución DNS
que descarte direcciones loopback, privadas, link-local, CGNAT y ULA; las
redirecciones se siguen manualmente (máximo 3) revalidando cada destino.

**Límites.** Timeout de 10 s, 10 peticiones por minuto por sesión, cuerpo de
hasta 256 KiB (límite efectivo ≈64 KB por el tamaño máximo del mensaje del
enlace), imágenes JPEG/PNG de hasta 64 KiB. Tipos admitidos: `text/plain`,
`application/json`, `text/html` (se muestra como texto, nunca se ejecuta) e
imagen. Los errores devuelven `ERROR_WEB` con `destino_rechazado` (más
`motivo`), `limite`, `timeout`, `sin_internet`, `demasiado_grande` o
`formato_no_admitido`.

**Caché en B.** Guarda `url → respuesta` con fecha (máximo 30 entradas, LRU). La
respuesta de la red lleva la insignia **RED**; si no hay Bluetooth, A no
responde en 20 s o se pierde el enlace, y la URL está en caché, se muestra con la
insignia **CACHÉ · dd/MM HH:mm**. Una `req` repetida devuelve la respuesta
guardada sin salir de nuevo a Internet. B tiene barra de dirección con los
recursos de prueba, atrás/adelante y favoritos.

**Cómo reproducirlo (B en modo avión + Bluetooth).**

1. En A: Wi-Fi o datos activos y Bluetooth encendido. Gestor → ⋮ → **Consulta
   web por Bluetooth** → **Servidor (A)**.
2. En B: activar el modo avión y luego solo Bluetooth (sin Wi-Fi ni datos).
   Abrir la misma pantalla → **Cliente (B)** → **Buscar servidores** → elegir
   `P6-web-…`.
3. En B: elegir un recurso en la barra de dirección y pulsar **Ir**. Deben verse
   RED, estado, tiempo en ms y el contenido.
4. Apagar Bluetooth en A y repetir la URL: B muestra CACHÉ con fecha. Otra URL
   no cacheada: error.
5. Rechazos: pedir `https://example.com/`, `https://192.168.1.1/` y
   `https://localhost/`.

---

## Compilación y ejecución

Requisitos: Flutter 3.47.6 (Dart 3.13.5), JDK 21 y Android SDK 36. **No se usa
emulador de Android:** todo se prueba en teléfonos físicos por USB con
depuración USB activada.

### Android

```bash
# Paquetes
for p in comun sensores enlace_ble consulta_web; do
  (cd packages/$p && flutter pub get && flutter test)
done

# Apps
cd apps/gestor_archivos
flutter pub get
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

cd ../juego_pares
flutter pub get
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Con dos teléfonos conectados, se indica el destino con
`adb -s <serie> install -r …` (`adb devices` lista los números de serie). Los
APK release se copian a [`apk/`](apk/) y se publican como artefactos del
workflow **CI Android**.

### iOS (sin Mac: Codemagic)

No hay Mac ni iPhone. `codemagic.yaml` define tres workflows que se ejecutan en
`mac_mini_m2` con Flutter 3.47.6:

| Workflow | Qué hace |
|---|---|
| `ios-gestor-capturas` | Analiza, prueba, arranca un simulador, corre la prueba de integración con capturas y compila `Runner.app` |
| `ios-juego-capturas` | Lo mismo para el juego |
| `ios-paquetes` | `flutter analyze` y `flutter test` de `sensores` y `enlace_ble` |

El simulador no tiene Bluetooth ni sensores: solo se verifica que las apps abren
y degradan con mensajes claros.

---

## Guía para reproducir los pares probados

Dos teléfonos Android con ambos APK instalados (T1 = propio, T2 = prestado).
Bluetooth encendido en ambos; se registra modelo y versión de Android de cada uno.

**Partida por Bluetooth (juego)**

1. T1 y T2: abrir **Pares IPN** → pestaña **Bluetooth**.
2. T1: **Anfitrión** y conceder el permiso de «dispositivos cercanos».
3. T2: **Unirse**, conceder el permiso y elegir la partida de T1 en la lista.
4. T1: **Aceptar** en «¿Aceptar a …?». Ambos deben mostrar «Conectado» y el
   mismo tablero.
5. Jugar por turnos; probar Diagnóstico (duplicado, fuera de turno, jugada
   inválida, `v:2`) y apagar Bluetooth en T2 para ver **Reintentar conexión**.

**Transferencia (gestor)**

1. T1: **Compartir** → **Recibir archivos**.
2. T2: en el explorador elegir `nota.txt` (o `datos.json`, `config.xml`,
   `foto.jpg`) → ⋮ → enviar; elegir el dispositivo de T1.
3. T1: aceptar la oferta. Verificar el archivo en `recibidos/` y el estado
   `completado` en ambos historiales.
4. Repetir con Ajustes → Diagnóstico → «Alterar un bloque»: el receptor debe
   marcar `fallido` y no dejar archivo.

**Consulta web:** ver «Ejercicio 3» (A = T1 con Internet; B = T2 en modo avión +
Bluetooth).

---

## Pruebas

- **Automatizadas:** `comun` 10, `sensores` 13, `enlace_ble` 56, `consulta_web`
  31, gestor 54 y juego 35. Cubren detectores y controlador de sensores,
  fragmentación, sobre, duplicados y protocolo sobre transporte en memoria,
  validador y caché web, transferencia, reglas del juego en red y widgets.
- **Dispositivos:** la matriz de casos (SEN, BIO, PER, JUE, ARC, WEB, ACC, IOS…)
  con pasos, esperado, obtenido y evidencia está en
  [`docs/pruebas.md`](docs/pruebas.md). Un caso bloqueado se documenta como
  tal y no se cuenta como aprobado; lo no ejecutado permanece `pendiente`.
- **iOS:** simulador en Codemagic, solo apertura y degradación.

---

## Evidencias

### Android

_Pendiente: se agrega tras la sesión en dispositivos._

### iOS

_Pendiente: se agrega tras la sesión en dispositivos._

### Video

_Pendiente: se agrega tras la sesión en dispositivos._

---

## Proceso

- **Ramas y PR:** el trabajo se hizo en ramas de funcionalidad integradas a
  `develop` mediante los pull requests #8 a #15; los issues #1 a #7 describen
  las tareas. Al final, un PR de `develop` a `main`.
- **CI:** el workflow **CI Android** (`.github/workflows/ci.yml`) corre
  `flutter analyze` y `flutter test` en `comun`, `sensores`, `enlace_ble` y
  `consulta_web`, y en cada app además compila el APK release. Codemagic cubre iOS.
- **GitHub Project:** _Pendiente: enlace al tablero._

---

## Uso de IA

Se usó Claude Code para generar código, documentación y pruebas; el autor
definió el alcance y el diseño y revisó el resultado. La declaración, cómo se
verificó y los errores de la IA detectados están en
[`README for IAS/uso-ia.md`](README%20for%20IAS/uso-ia.md).

---

## Problemas conocidos y limitaciones

- **Sin iPhone:** Android↔iOS e iOS↔iOS están **no verificados**; el simulador
  de iOS no tiene Bluetooth ni sensores.
- **Android↔Android** está `pendiente de evidencia` hasta la sesión en
  dispositivos; los resultados pueden variar con otros modelos (MTU, caudal).
- **Segundo teléfono prestado:** solo se declaran los modelos realmente usados.
- **Sin trabajo en segundo plano:** la sesión BLE puede perderse al minimizar.
- **Sin reanudación de archivos** y límite de 512 KiB.
- **SHA-256 no autentica;** el cifrado del enlace depende del emparejamiento del
  sistema y no hay criptografía propia. El servicio GATT acepta a cualquier
  central cercano, con confirmación del usuario.
- **Consulta web acotada** a cuatro dominios de prueba; no es un navegador. Una
  respuesta mayor a ≈64 KB se devuelve como `demasiado_grande`.
- **RFCOMM no implementado.**
- **Android ≤ 11** exige ubicación para escanear BLE.
- **Biometría** depende de lo enrolado en el teléfono de prueba y no cifra la Bóveda.
- **Sin emulador de Android:** todo en teléfonos físicos.

---

## Conclusiones

_Pendiente_

---

## Referencias (APA)

Android Developers. (s. f.). *Bluetooth permissions*. https://developer.android.com/develop/connectivity/bluetooth/bt-permissions

Android Developers. (s. f.). *Bluetooth Low Energy overview*. https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview

Apple. (s. f.). *Core Bluetooth*. https://developer.apple.com/documentation/corebluetooth

Bluetooth SIG. (s. f.). *Assigned numbers*. https://www.bluetooth.com/specifications/assigned-numbers/

National Institute of Standards and Technology. (2015). *Secure Hash Standard (SHS)* (FIPS PUB 180-4). https://csrc.nist.gov/pubs/fips/180-4/upd1/final

Flutter. (s. f.). *Flutter documentation*. https://docs.flutter.dev/

*sensors_plus* [Paquete de software]. (s. f.). pub.dev. https://pub.dev/packages/sensors_plus

*local_auth* [Paquete de software]. (s. f.). pub.dev. https://pub.dev/packages/local_auth

*bluetooth_low_energy* [Paquete de software]. (s. f.). pub.dev. https://pub.dev/packages/bluetooth_low_energy

*permission_handler* [Paquete de software]. (s. f.). pub.dev. https://pub.dev/packages/permission_handler
