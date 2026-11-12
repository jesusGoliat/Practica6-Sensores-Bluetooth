# Practice 6 — Mobile device sensor handling

[Versión en español](README.md)

## Cover page

- **Full name:** Jesús Ángel González Arellano
- **Student ID:** 2022630690
- **Group:** 7CV4
- **Course:** Native mobile application development (Desarrollo de aplicaciones móviles nativas)
- **Professor:** Gabriel Hurtado Avilés
- **Due date:** November 12, 2026

---

## Repository structure

```text
README.md                        Report (Spanish)
README.en.md                     This report (English)
apps/gestor_archivos/            App 1 "Archivos IPN": + BLE transfer, biometrics, shake, web query
apps/juego_pares/                App 2 "Pares IPN": + BLE match, sensor control
packages/comun/                  Shared themes, texts, highlighting and widgets (from Practice 4)
packages/sensores/               Accelerometer and gyroscope behind an interface, detectors, panel
packages/enlace_ble/             Protocol (pure Dart) and BLE central/peripheral transport
packages/consulta_web/           Web query over Bluetooth: server A, client B, validator, cache
packages/selector_carpetas_ios/  Swift plugin: document picker + security-scoped bookmark (Practice 4)
docs/                            diseno-p6, protocolo, arquitectura, pruebas, implementacion, images
README for IAS/                  Notes for AI assistants and AI-use declaration
apk/                             Release APKs of both apps
tools/                           Resource generation, screenshots and evidence helpers
.github/                         CI (Android) and evidence workflows
codemagic.yaml                   iOS (simulator) workflows on Codemagic
```

The documents under `docs/` and `README for IAS/` are written in Spanish.

---

## Summary

The two Flutter apps from Practice 4 were extended for Android 7.0+ (API 24)
and iOS 15+ with three exercises:

1. **Sensors and interaction:** accelerometer and gyroscope with a live panel,
   absence detection, pause/resume tied to the app lifecycle, and biometrics for
   sensitive actions.
2. **File transfer and a match over Bluetooth Low Energy (BLE)** between two
   devices, using a custom protocol with MTU-based fragmentation, ACKs,
   duplicate control and SHA-256 verification.
3. **Web query over Bluetooth:** a device without Internet (B) fetches an HTTPS
   resource from an allowlist through another device with Internet (A).

No Firebase, Wi-Fi Direct or Internet between the devices is used.

| App | `applicationId` | Practice 6 additions |
|---|---|---|
| **Archivos IPN** | `mx.ipn.escom.p6.gestorarchivos` | Sensors, shake to refresh, biometrics (Delete and Vault), BLE transfer, web query |
| **Pares IPN** | `mx.ipn.escom.p6.juegopares` | Sensors, tilt and twist control, BLE match between two devices |

| Document | Content |
|---|---|
| [`docs/diseno-p6.md`](docs/diseno-p6.md) | Design contract: names, types, messages and rules |
| [`docs/protocolo.md`](docs/protocolo.md) | GATT, advertising, fragmentation, JSON envelope, types, errors, diagrams |
| [`docs/arquitectura.md`](docs/arquitectura.md) | Components, layers, state machines, permissions, security, limits |
| [`docs/pruebas.md`](docs/pruebas.md) | Criteria, risks and test case matrix |
| [`docs/implementacion.md`](docs/implementacion.md) | Practice 4 base (files and serialization) |
| [`README for IAS/`](README%20for%20IAS/README.md) | AI notes, decisions, status, limitations and AI use |
| [`packages/enlace_ble/README.md`](packages/enlace_ble/README.md) | Protocol and transport details |
| [`packages/consulta_web/README.md`](packages/consulta_web/README.md) | Web query details |

---

## Technology and versions

| Tool | Version |
|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 |
| Android Gradle Plugin / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0 |
| JDK | 21 |
| Android `minSdk` / `targetSdk` / `compileSdk` | 24 / 36 / 36 |
| iOS deployment target | 15.0 |
| iOS | Simulator only, on Codemagic (`mac_mini_m2`); no Bluetooth or sensors |

New plugins in this practice, with the version resolved in the `pubspec.lock` files:

| Plugin | Resolved version | Use | Where |
|---|---|---|---|
| `sensors_plus` | 7.1.1 | Accelerometer and gyroscope | `packages/sensores`, both apps |
| `local_auth` | 3.0.2 | Biometrics / device credential | `gestor_archivos` only |
| `bluetooth_low_energy` | 6.2.1 | BLE central and peripheral roles | `packages/enlace_ble`, both apps |
| `permission_handler` | 12.0.3 | Permissions and permanent denial | `packages/enlace_ble`, both apps |
| `crypto` | 3.0.8 | SHA-256 | Both apps |

`permission_handler` is pinned to **12.x** (`^12.0.1`): 13.x requires
`compileSdk` 37, which AGP 9.1 does not support (it recommends 36 at most). The
exact versions are in each `pubspec.lock`, which is committed so builds are
reproducible.

---

## Exercise 1 — Sensors and interaction

**What is read.** Accelerometer (`m/s²`) and gyroscope (`rad/s`) through the
`FuenteSensor` interface of the `sensores` package. There is a physical
implementation (`FuenteSensoresPlus`) and a simulated one (`FuenteSimulada`), so
the logic can be tested without hardware.

**Where it is in the UI.**

- **File manager:** ⋮ menu on the main screen → **Sensores**; Settings →
  **Sensores** ("Sacudir para actualizar") and **Diagnóstico** ("Usar sensores
  simulados").
- **Game:** Settings → **Sensores** (live panel, "Usar valores simulados" and
  "Simular sensor ausente"); on the board, the **Control por movimiento** switch.

The panel shows x/y/z, unit, reading timestamp, state and a **FÍSICA**
(physical) or **SIMULADA** (simulated) badge, plus a log of pauses, resumes and
absences.

**What the readings do.**

| App | Gesture | Effect |
|---|---|---|
| File manager | Shake (magnitude minus gravity > 15 m/s², 800 ms cooldown) | Refreshes the current folder listing |
| Game | Tilt (accelerometer, threshold 3.5 m/s², 350 ms repeat) | Moves a cursor over the board |
| Game | Fast wrist twist (gyroscope, \|y\| or \|z\| > 4 rad/s, 800 ms cooldown) | Flips the card under the cursor |

**Sampling period: 100 ms (about 10 readings per second per sensor).** It is
enough to detect gestures lasting tens of milliseconds and to update the panel
smoothly, and it avoids the battery and CPU cost of higher rates (Android allows
up to 200 Hz without a permission). Cooldowns keep one movement from triggering
the action several times.

**Sensor absence.** `FuenteSensor.disponible()` returns `false` if the phone has
no such sensor; the state becomes `ausente` (absent) with a readable message and
the app does not crash. If a sensor stops emitting for more than 2 s the state is
`sinDatos` (no data) and it recovers when readings resume.

**Pause and resume.** When the app goes to the background
(`AppLifecycleState.paused/inactive/hidden`) and when leaving the screen, the
subscriptions are cancelled; on `resumed` they are restarted. Every change is
logged.

**Simulated vs. physical.** The simulated source (normal, extreme and absent
scenarios) demonstrates cases the hardware does not produce easily and serves the
iOS simulator, which has no sensors. The badge always states which source is in
use; readings are never mixed.

**Biometrics (file manager only).** `local_auth` protects **Delete** and the
**Vault** (private `protegido/` folder). `biometricOnly: false` is used, so when
no fingerprint is enrolled the system PIN/pattern is offered; if the phone has no
screen lock at all, the action is blocked with an explanation. A cancelled or
failed authentication does not run the action. Limits: the app only receives a
yes/no from the system, never the fingerprint; biometrics do not encrypt the
Vault files and depend on what is enrolled on the test phone.

---

## Match over Bluetooth

**Roles.** Either device chooses in the game's **Bluetooth** tab: **Anfitrión**
(host, peripheral: advertises and accepts) or **Unirse** (join, central: scans
and connects). Permissions are requested when a role is chosen, not at app start.

**Flow.**

1. The host advertises; the guest scans and picks the match from the list.
2. The guest sends `HOLA`; the host sees "¿Aceptar a …?" and answers `ACEPTA` or
   `RECHAZA`.
3. The host sends `PARTIDA_NUEVA{semilla, nivel, anfitrionEmpieza, idPartida}`;
   both build the same board from the same seed.
4. Players alternate sending `JUGADA{indice, jugador, turno}`. The receiver
   checks it is the sender's turn, the counter matches, and the index is in
   range and the card free; otherwise it replies `ERROR{turno|jugada}` and the
   state does not change.
5. `FIN{ganador, puntos}` ends the match; both show the same result.

**Messages:** `HOLA`, `ACEPTA`, `RECHAZA`, `ACK`, `PING`, `ADIOS`, `ERROR`,
`PARTIDA_NUEVA`, `JUGADA`, `ESTADO`, `REANUDAR`, `FIN` (see
[`docs/protocolo.md`](docs/protocolo.md)).

**Duplicate control.** Each sender numbers `seq` per session; an already
processed `seq` is ignored (the `ACK` is resent) and never re-applied. The sender
waits 3 s for the `ACK` and retries 3 times. Diagnostics offers actions to
resend the last move, play out of turn, send an invalid move and send `v:2`,
which demonstrate those rejections.

**Reconnection and persistence.** If the link drops, both sides show "Conexión
perdida" and **Reintentar conexión**; on reconnect,
`REANUDAR{idPartida, ultimoSeq}` resumes the same board and turn. The state of
the networked match is persisted: after restarting the app it offers **Recuperar
partida** or a notice that the match ended, with the reason.

---

## Transport compatibility

**BLE GATT.** One custom service (`6f1c0001-9b5a-4c1e-8f7e-0c0ffee00006`) with an
RX characteristic (central → peripheral, write / write without response) and a TX
characteristic (peripheral → central, notify). The full specification, fragment
header, JSON envelope and error codes are in
[`docs/protocolo.md`](docs/protocolo.md).

**MTU-based fragmentation.** There is no universal size. The central requests MTU
512 (Android) and reads the maximum write length; the peripheral uses the
central's maximum notify length. The useful fragment is the negotiated length
minus a 5-byte header; if it cannot be read, 20 bytes are used (MTU 23 − 3). The
reassembler drops incomplete messages after 10 s and caps each message at 64 KiB.

**Advertising: Android without a local name.** On Android, the plugin implements
the local name with `BluetoothAdapter.setName()`, which would rename the whole
phone, and it also does not fit next to the 128-bit UUID in the 31-byte
advertisement. So an Android host advertises the service UUID plus
**manufacturer data** (id `0xFFFF`: bytes `'P'`, `'6'`, app code 1 game / 2 files
/ 3 web, and a 2-byte suffix). The central rebuilds the name
`P6-<app>-<4 hex>`. iOS does advertise the local name in that format.

**RFCOMM not implemented.** RFCOMM (classic Bluetooth) does not exist on iOS; BLE
was chosen because it can, in theory, interoperate with iOS. No RFCOMM
compatibility is claimed.

**Pair and transport matrix.**

| Pair | Transport | Status |
|---|---|---|
| Android ↔ Android | BLE GATT | `pendiente de evidencia` (pending evidence, filled in after the device session) |
| Android ↔ iOS | BLE GATT | Not verified (no iPhone) |
| iOS ↔ iOS | BLE GATT | Not verified (no iPhone) |
| Any | RFCOMM | Not implemented |

The code uses cross-platform APIs, but iOS compatibility is not claimed: the iOS
simulator has no Bluetooth.

---

## Exercise 2 — File transfer

In the file manager, the **Compartir** tab: one phone turns on **Recibir
archivos** (peripheral, advertised as `P6-archivos-…`) and the other (central)
searches, connects and sends the file chosen from the explorer (⋮ menu).

- **Types and limits:** `txt`, `json`, `xml`, `jpg` (`.jpeg` is normalized);
  maximum **512 KiB**; 2 KiB blocks (base64 in the envelope) with a `BLOQUE_ACK`
  per block; a queue of up to 5 sends.
- **Explicit acceptance:** the receiver sees the offer (`OFERTA`) and decides; it
  may reject (`OFERTA_RECHAZA`) or cancel at any time.
- **Name validation:** only `[A-Za-z0-9._ -áéíóúñÁÉÍÓÚÑ]`, no `/`, `\` or `..`,
  at most 80 characters, extension consistent with the type. Destination:
  `recibidos/` in the private space; if it exists, ` (2)` is appended.
- **Integrity:** the receiver writes to `tmp/<id>.part`, verifies length and
  **SHA-256**, and only then renames. On failure it deletes the temporary file
  and marks the transfer `fallido`. SHA-256 detects tampering or corruption; it
  **does not authenticate**.
- **States:** `pendiente`, `enCurso`, `completado`, `cancelado`, `fallido`, with a
  persisted history; on restart, orphaned pending or in-progress transfers become
  `fallido` ("interrumpida por reinicio"). There is no resume: re-sending starts
  at block 0.
- **Diagnostics** (Settings): "Alterar un bloque" and "Enviar nombre inválido" to
  demonstrate rejection by integrity and by validation.

---

## Permissions and lifecycle

Permissions declared in the `src/main` `AndroidManifest.xml` files and the
`Info.plist` keys:

| Permission / key | Android 12+ (API 31+) | Android ≤ 11 (API ≤ 30) | Role | Apps |
|---|---|---|---|---|
| `BLUETOOTH_SCAN` (`neverForLocation`) | Yes | — | Central: scan | Both |
| `BLUETOOTH_CONNECT` | Yes | — | Central and peripheral | Both |
| `BLUETOOTH_ADVERTISE` | Yes | — | Peripheral: advertise | Both |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (`maxSdkVersion=30`) | — | Yes | Both | Both |
| `ACCESS_FINE_LOCATION` (`maxSdkVersion=30`) | — | Yes (required to scan and by the plugin) | Both | Both |
| `USE_BIOMETRIC` | Yes | Yes | Biometrics | File manager only |
| `INTERNET` | Yes | Yes | Device A of the web query only | File manager only |
| `uses-feature` BLE, accelerometer, gyroscope (`required=false`) | Yes | Yes | The app installs even without the hardware | Both |
| `NSBluetoothAlwaysUsageDescription` (iOS) | — | — | Bluetooth | Both |
| `NSFaceIDUsageDescription` (iOS) | — | — | Face ID | File manager only |

- There is no motion usage string in `Info.plist`: sensors need no permission on
  Android (sampling ≤ 200 Hz) and the iOS simulator has none.
- `POST_NOTIFICATIONS` is not declared. Notices are **local and in-app** (for
  example, a transfer finishing while the app is open or just minimized); no FCM
  or Firebase is used.
- **Foreground only:** there are no background services. Minimizing cancels sensor
  subscriptions and a BLE session may be lost; on return the user is informed and
  offered a reconnect (game) or the transfer is marked `fallido` (files).
- Permissions are requested in context, with a prior explanation and handling of
  denied, permanently denied (button to the app settings) and revoked.
- No location on Android 12+ or in the background, and no broad storage access.

---

## Exercise 3 — Web query over Bluetooth

**Roles.** **A (server)** has Internet, advertises as `P6-web-…`, receives
`PETICION{req, url}`, validates and performs the HTTPS request. **B (client)**
uses no Wi-Fi or mobile data, only Bluetooth, and **never makes HTTP requests**.

**Allowlist** (port 443, HTTPS):

| Domain | Test resources |
|---|---|
| `jsonplaceholder.typicode.com` | `/todos/1`, `/posts/1`, `/users/1` |
| `httpbin.org` | `/json`, `/uuid`, `/image/jpeg` (≈35 KB) |
| `api.github.com` | `/zen` |
| `www.ipn.mx` | `/robots.txt` |

**Validations on A (at every hop):** `https` scheme; no credentials in the URL;
host is not a literal IP; host in the list; port 443; DNS resolution that rejects
loopback, private, link-local, CGNAT and ULA addresses; redirects are followed
manually (at most 3), revalidating each destination.

**Limits.** 10 s timeout, 10 requests per minute per session, body up to 256 KiB
(effective limit ≈64 KB because of the link's maximum message size), JPEG/PNG
images up to 64 KiB. Accepted types: `text/plain`, `application/json`,
`text/html` (shown as text, never executed) and images. Errors return
`ERROR_WEB` with `destino_rechazado` (plus `motivo`), `limite`, `timeout`,
`sin_internet`, `demasiado_grande` or `formato_no_admitido`.

**Cache on B.** Stores `url → response` with a date (at most 30 entries, LRU). A
network response carries the **RED** badge; if there is no Bluetooth, A does not
answer within 20 s or the link is lost, and the URL is cached, it is shown with
the **CACHÉ · dd/MM HH:mm** badge. A repeated `req` returns the stored response
without going to the Internet again. B has an address bar with the test
resources, back/forward and favorites.

**How to reproduce it (B in airplane mode + Bluetooth).**

1. On A: Wi-Fi or mobile data on and Bluetooth on. File manager → ⋮ → **Consulta
   web por Bluetooth** → **Servidor (A)**.
2. On B: turn on airplane mode, then enable only Bluetooth (no Wi-Fi or data).
   Open the same screen → **Cliente (B)** → **Buscar servidores** → pick
   `P6-web-…`.
3. On B: pick a resource in the address bar and press **Ir**. RED, status, time in
   ms and the content must appear.
4. Turn Bluetooth off on A and repeat the URL: B shows CACHÉ with a date. Another,
   uncached URL: error.
5. Rejections: request `https://example.com/`, `https://192.168.1.1/` and
   `https://localhost/`.

---

## Build and run

Requirements: Flutter 3.47.6 (Dart 3.13.5), JDK 21 and Android SDK 36. **No
Android emulator is used:** everything is tested on physical phones over USB with
USB debugging enabled.

### Android

```bash
# Packages
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

With two phones attached, choose the target with `adb -s <serial> install -r …`
(`adb devices` lists serial numbers). Release APKs are copied to [`apk/`](apk/)
and published as artifacts of the **CI Android** workflow.

### iOS (no Mac: Codemagic)

There is no Mac or iPhone. `codemagic.yaml` defines three workflows that run on
`mac_mini_m2` with Flutter 3.47.6:

| Workflow | What it does |
|---|---|
| `ios-gestor-capturas` | Analyzes, tests, boots a simulator, runs the screenshot integration test and builds `Runner.app` |
| `ios-juego-capturas` | The same for the game |
| `ios-paquetes` | `flutter analyze` and `flutter test` for `sensores` and `enlace_ble` |

The simulator has no Bluetooth or sensors: it only verifies that the apps open
and degrade with clear messages.

---

## Guide to reproduce the tested pairs

Two Android phones with both APKs installed (T1 = own, T2 = borrowed). Bluetooth
on in both; the model and Android version of each are recorded.

**Match over Bluetooth (game)**

1. T1 and T2: open **Pares IPN** → **Bluetooth** tab.
2. T1: **Anfitrión** and grant the "nearby devices" permission.
3. T2: **Unirse**, grant the permission and pick T1's match from the list.
4. T1: **Aceptar** in "¿Aceptar a …?". Both must show "Conectado" and the same
   board.
5. Play in turns; try Diagnostics (duplicate, out of turn, invalid move, `v:2`)
   and turn Bluetooth off on T2 to see **Reintentar conexión**.

**Transfer (file manager)**

1. T1: **Compartir** → **Recibir archivos**.
2. T2: in the explorer pick `nota.txt` (or `datos.json`, `config.xml`,
   `foto.jpg`) → ⋮ → send; choose T1's device.
3. T1: accept the offer. Check the file in `recibidos/` and the `completado`
   state in both histories.
4. Repeat with Settings → Diagnóstico → "Alterar un bloque": the receiver must
   mark `fallido` and leave no file.

**Web query:** see "Exercise 3" (A = T1 with Internet; B = T2 in airplane mode +
Bluetooth).

---

## Tests

- **Automated:** `comun` 10, `sensores` 13, `enlace_ble` 56, `consulta_web` 31,
  file manager 54 and game 35. They cover sensor detectors and controller,
  fragmentation, envelope, duplicates and the protocol over an in-memory
  transport, the web validator and cache, transfer, networked game rules and
  widgets.
- **Devices:** the case matrix (SEN, BIO, PER, JUE, ARC, WEB, ACC, IOS…) with
  steps, expected, obtained and evidence is in [`docs/pruebas.md`](docs/pruebas.md).
  A blocked case is documented as such and not counted as passed; anything not
  run stays `pendiente`.
- **iOS:** simulator on Codemagic, open-and-degrade checks only.

---

## Evidence

### Android

_Pending: added after the device session._

### iOS

_Pending: added after the device session._

### Video

_Pending: added after the device session._

---

## Process

- **Branches and PRs:** work was done on feature branches merged into `develop`
  through pull requests #8 to #15; issues #1 to #7 describe the tasks. At the end,
  a PR from `develop` to `main`.
- **CI:** the **CI Android** workflow (`.github/workflows/ci.yml`) runs
  `flutter analyze` and `flutter test` on `comun`, `sensores`, `enlace_ble` and
  `consulta_web`, and for each app also builds the release APK. Codemagic covers
  iOS.
- **GitHub Project:** _Pending: link to the board._

---

## Use of AI

Claude Code was used to generate code, documentation and tests; the author
defined the scope and design and reviewed the result. The declaration, how it was
verified and the AI errors that were detected are in
[`README for IAS/uso-ia.md`](README%20for%20IAS/uso-ia.md) (Spanish).

---

## Known issues and limitations

- **No iPhone:** Android↔iOS and iOS↔iOS are **not verified**; the iOS simulator
  has no Bluetooth or sensors.
- **Android↔Android** is `pendiente de evidencia` until the device session;
  results may vary with other models (MTU, throughput).
- **Borrowed second phone:** only the models actually used are declared.
- **No background work:** the BLE session may be lost when the app is minimized.
- **No file resume** and a 512 KiB limit.
- **SHA-256 does not authenticate;** link encryption depends on system pairing and
  there is no custom cryptography. The GATT service accepts any nearby central,
  with user confirmation.
- **Web query limited** to four test domains; it is not a browser. A response
  larger than ≈64 KB is returned as `demasiado_grande`.
- **RFCOMM not implemented.**
- **Android ≤ 11** requires location to scan for BLE.
- **Biometrics** depend on what is enrolled on the test phone and do not encrypt
  the Vault.
- **No Android emulator:** everything runs on physical phones.

---

## Conclusions

_Pendiente_

---

## References (APA)

Android Developers. (n.d.). *Bluetooth permissions*. https://developer.android.com/develop/connectivity/bluetooth/bt-permissions

Android Developers. (n.d.). *Bluetooth Low Energy overview*. https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview

Apple. (n.d.). *Core Bluetooth*. https://developer.apple.com/documentation/corebluetooth

Bluetooth SIG. (n.d.). *Assigned numbers*. https://www.bluetooth.com/specifications/assigned-numbers/

National Institute of Standards and Technology. (2015). *Secure Hash Standard (SHS)* (FIPS PUB 180-4). https://csrc.nist.gov/pubs/fips/180-4/upd1/final

Flutter. (n.d.). *Flutter documentation*. https://docs.flutter.dev/

*sensors_plus* [Software package]. (n.d.). pub.dev. https://pub.dev/packages/sensors_plus

*local_auth* [Software package]. (n.d.). pub.dev. https://pub.dev/packages/local_auth

*bluetooth_low_energy* [Software package]. (n.d.). pub.dev. https://pub.dev/packages/bluetooth_low_energy

*permission_handler* [Software package]. (n.d.). pub.dev. https://pub.dev/packages/permission_handler
