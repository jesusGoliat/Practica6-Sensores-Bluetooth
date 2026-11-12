# Práctica 4 — Gestión de archivos multiplataforma (Android e iOS)

## Portada

- **Nombre completo:** Jesús Ángel González Arellano
- **Número de boleta:** 2022630690
- **Grupo:** 7CV4
- **Asignatura:** Desarrollo de aplicaciones móviles nativas
- **Profesor(a):** Gabriel Hurtado Avilés
- **Fecha de entrega:** 5 de noviembre de 2026

---

## Estructura del repositorio

```text
README.md                       Este informe
apps/gestor_archivos/           App 1: explorador, visores y operaciones de archivos
apps/juego_pares/               App 2: memorama con partidas TXT/XML/JSON
packages/comun/                 Temas, textos, resaltado y widgets compartidos
packages/selector_carpetas_ios/ Plugin Swift: document picker + security-scoped bookmark
docs/implementacion.md          Arquitectura, SAF, document picker y serialización
docs/pruebas.md                 Plan, riesgos y matriz de 24 casos
docs/img/                       Evidencias Android e iOS
apk/                            APK release de las dos apps
tools/                          Generación de recursos y selección de simulador
.github/workflows/              CI Android y compilación/evidencia iOS
```

---

## Resumen

Se desarrollaron **dos aplicaciones Flutter independientes**, 100 % offline,
para Android 7.0+ (API 24) e iOS 15+:

| App | `applicationId` | Funciones principales |
|---|---|---|
| **Archivos IPN** | `mx.ipn.escom.p4.gestorarchivos` | Explorador del espacio privado y carpetas autorizadas (SAF en Android, document picker en iOS), visores TXT/MD/JSON/XML/imagen, metadatos, favoritos, recientes, caché de miniaturas, copiar/mover/renombrar/eliminar, abrir/compartir/exportar formatos no soportados |
| **Pares IPN** | `mx.ipn.escom.p4.juegopares` | Memorama original con niveles Campus 4×4 y Laboratorio 6×6, modos Relajado y Contrarreloj, puntaje, tiempo, racha, categorías, sonido, efectos y partidas guardadas/cargadas en TXT, XML y JSON |

Las dos apps comparten el paquete `comun` (temas Guinda/Azul, textos en
español, resaltado de sintaxis, MIME/UTType, breadcrumbs y diálogos). Así se
evita que las dos versiones digan o se vean distinto.

| Documento | Contenido |
|---|---|
| [`docs/implementacion.md`](docs/implementacion.md) | Arquitectura, APIs de archivos, serialización y validación |
| [`docs/pruebas.md`](docs/pruebas.md) | Criterios, riesgos, matriz de 24 casos y resultados |
| [`apps/gestor_archivos/README.md`](apps/gestor_archivos/README.md) | Detalle y comandos de la app 1 |
| [`apps/juego_pares/README.md`](apps/juego_pares/README.md) | Detalle y comandos de la app 2 |

---

## Tecnología y versiones

| Herramienta | Versión |
|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 |
| Android Gradle Plugin / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0 |
| JDK | 21 |
| Android `minSdk` / `targetSdk` / `compileSdk` | 24 / 36 / 36 |
| iOS deployment target | 15.0 |
| Simulador iOS de evidencia | iPhone SE (3.ª generación), iOS 26.2, en GitHub Actions `macos-15` |
| Xcode usado en CI | El disponible en `macos-15`; se imprime en el log del workflow |
| Paquetes principales | `saf`, `file_picker`, `share_plus`, `open_filex`, `path_provider`, `shared_preferences`, `image`, `xml`, `mime`, `audioplayers`, `crypto`, `provider` |

Las versiones exactas resueltas quedan en cada `pubspec.lock`, que se versiona
para reproducir la compilación.

---

## Parte 1 — Archivos IPN

- **Espacio propio:** siempre disponible; todas las operaciones están
  garantizadas dentro del contenedor de la app.
- **Carpetas autorizadas:** Android usa SAF (`ACTION_OPEN_DOCUMENT_TREE`) con
  permiso persistible; iOS usa `UIDocumentPickerViewController` y un bookmark
  con security scope. La app solo ve lo que el usuario autoriza.
- **Visores:** texto y Markdown en monoespaciado, JSON y XML embellecidos y con
  resaltado de sintaxis, imágenes con zoom por pellizco, paneo, doble toque y
  rotación de 90°.
- **Formatos no soportados:** diálogo con Abrir con otra app, Compartir y
  Exportar mediante el sistema operativo.
- **Metadatos:** nombre, tamaño, modificación, creación (o “No disponible”),
  MIME y UTType.
- **Persistencia:** favoritos y recientes en `shared_preferences`; miniaturas en
  una caché temporal con poda LRU.
- **Seguridad:** sin permisos globales de almacenamiento; validación de rutas,
  destino y nombre antes de escribir; confirmación de acciones destructivas;
  mensajes claros para permisos revocados, rutas inexistentes, errores de
  lectura o espacio insuficiente.

### Evidencia Android del gestor

| Inicio | Tema Azul | Explorador | Visor JSON |
|---|---|---|---|
| ![Inicio](docs/img/android/gestor/01-inicio-guinda.png) | ![Azul](docs/img/android/gestor/02-tema-azul.png) | ![Explorador](docs/img/android/gestor/03-explorador.png) | ![JSON](docs/img/android/gestor/04-visor-json.png) |

| Visor XML | Visor imagen | Imagen girada | Recientes | Modo oscuro |
|---|---|---|---|---|
| ![XML](docs/img/android/gestor/05-visor-xml.png) | ![Imagen](docs/img/android/gestor/06-visor-imagen.png) | ![Girada](docs/img/android/gestor/07-imagen-girada.png) | ![Recientes](docs/img/android/gestor/08-recientes.png) | ![Oscuro](docs/img/android/gestor/09-modo-oscuro.png) |

### Capturas iOS

El workflow `ios.yml` compila la app, la ejecuta en un simulador de iPhone y
toma capturas con `integration_test` + `flutter drive`.

### Evidencia iOS del gestor

| Inicio | Tema Azul | Explorador | Visor JSON |
|---|---|---|---|
| ![Inicio](docs/img/ios/gestor/01-inicio-guinda.png) | ![Azul](docs/img/ios/gestor/02-tema-azul.png) | ![Explorador](docs/img/ios/gestor/03-explorador.png) | ![JSON](docs/img/ios/gestor/04-visor-json.png) |

| Visor XML | Visor imagen | Imagen girada | Recientes | Modo oscuro |
|---|---|---|---|---|
| ![XML](docs/img/ios/gestor/05-visor-xml.png) | ![Imagen](docs/img/ios/gestor/06-visor-imagen.png) | ![Girada](docs/img/ios/gestor/07-imagen-girada.png) | ![Recientes](docs/img/ios/gestor/08-recientes.png) | ![Oscuro](docs/img/ios/gestor/09-modo-oscuro.png) |

---

## Parte 2 — Pares IPN

- **Juego original:** memorama temático del campus con símbolos de Ciencias,
  Ingeniería, Cómputo e IPN. Completar una categoría otorga una bonificación y
  un efecto de “circuito completado”.
- **Niveles y modos:** Campus 4×4 (8 parejas) y Laboratorio 6×6 (18 parejas);
  Relajado sin límite y Contrarreloj (90 s / 180 s).
- **Puntuación y progreso:** +100 por pareja, bonificación por racha, −10 por
  fallo, +150 por categoría y bonificación final; mejor puntaje y partidas
  jugadas persistentes.
- **Efectos:** volteo animado, pulso al emparejar y confeti al ganar; sonidos
  WAV generados localmente (voltear, acierto, error, victoria) con interruptor.
- **Partidas:** guardado y carga en **TXT, XML y JSON** con el formato elegido
  por el usuario; se guardan estado, puntaje, tiempo, configuración e historial
  de movimientos; lista con metadatos, etiquetas, filtros, exportación,
  compartición e importación.
- **Robustez:** escritura atómica, checksum FNV-1a, validación de archivos
  vacíos/incompletos/corruptos y autoguardado tras cada movimiento y al pasar a
  segundo plano. Un archivo dañado no borra las demás partidas.
- **Visor de partidas:** muestra el contenido del TXT/XML/JSON con el mismo
  resaltado del gestor.

### Evidencia Android del juego

| Inicio | Tablero 4×4 | Cartas volteadas | Pausa |
|---|---|---|---|
| ![Inicio](docs/img/android/juego/01-inicio.png) | ![Tablero](docs/img/android/juego/02-juego-4x4.png) | ![Cartas](docs/img/android/juego/03-cartas-volteadas.png) | ![Pausa](docs/img/android/juego/04-pausa.png) |

| Partida guardada | Lista de partidas | Contenido JSON | Tema Azul | Laboratorio 6×6 |
|---|---|---|---|---|
| ![Guardada](docs/img/android/juego/05-partida-guardada.png) | ![Lista](docs/img/android/juego/06-lista-partidas.png) | ![Contenido](docs/img/android/juego/07-contenido-json.png) | ![Ajustes](docs/img/android/juego/08-ajustes-tema-azul.png) | ![Lab](docs/img/android/juego/09-laboratorio-contrarreloj.png) |

### Evidencia iOS del juego

| Inicio | Tablero 4×4 | Cartas volteadas | Pausa |
|---|---|---|---|
| ![Inicio](docs/img/ios/juego/01-inicio.png) | ![Tablero](docs/img/ios/juego/02-juego-4x4.png) | ![Cartas](docs/img/ios/juego/03-cartas-volteadas.png) | ![Pausa](docs/img/ios/juego/04-pausa.png) |

| Partida guardada | Lista de partidas | Contenido JSON | Tema Azul |
|---|---|---|---|
| ![Guardada](docs/img/ios/juego/05-partida-guardada.png) | ![Lista](docs/img/ios/juego/06-lista-partidas.png) | ![Contenido](docs/img/ios/juego/07-contenido-json.png) | ![Ajustes](docs/img/ios/juego/08-ajustes-tema-azul.png) |


---

## Compilación y ejecución

### Android (Linux/Windows/macOS)

```bash
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

Los APK release también quedan en [`apk/`](apk/) y como artefactos del workflow
`CI Android`.

### iOS (macOS con Xcode)

Requisitos: macOS, Xcode 16 o superior, CocoaPods y Flutter 3.47.6.

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
flutter doctor
cd apps/gestor_archivos
flutter pub get
open ios/Runner.xcworkspace   # seleccionar un simulador de iPhone (iOS 15+)
flutter run -d "iPhone 16"
```

Para la app del juego se repite en `apps/juego_pares`. El proyecto usa Swift
Package Manager; si el entorno lo requiere, `cd ios && pod install`.

### iOS sin una Mac: GitHub Actions

El repositorio incluye `.github/workflows/ios.yml`. En cada push a `main` (o
manualmente desde la pestaña **Actions**):

1. Instala Flutter 3.47.6 en `macos-15`.
2. Ejecuta `flutter analyze` y `flutter test`.
3. Arranca un simulador iPhone disponible con `tools/elegir_simulador.py`.
4. Corre `flutter drive` con `integration_test/evidencia_ios_test.dart`, que
   navega y captura screenshots reales.
5. Compila `flutter build ios --simulator --debug` y publica la app y los PNG
   como artefactos.

Esto permite verificar iOS sin una Mac física. Las capturas usadas en este
informe provienen de esos artefactos.

---

## Pruebas realizadas

- **Automatizadas:** 43 pruebas (`comun` 10, gestor 14, juego 19) sobre
  resaltado, temas, MIME/UTType, operaciones de archivos, validación de rutas,
  caché, serialización TXT/XML/JSON, checksum, motor, puntaje y widgets.
- **Integración iOS:** recorridos con capturas en simulador para las dos apps.
- **Android:** recorridos en celular físico, incluyendo modo avión, operaciones
  SAF, guardado/carga y recuperación tras force-stop.

La matriz completa, con sistema, versión, dispositivo, pasos, esperado,
obtenido y evidencia, está en [`docs/pruebas.md`](docs/pruebas.md). Un caso
bloqueado se documenta como tal y no se cuenta como aprobado.

---

## Problemas conocidos y limitaciones

- En Android 11+ el selector SAF no permite autorizar la raíz del
  almacenamiento, la raíz de `Download`, `Android/data` ni `Android/obb`; es una
  restricción del sistema y se documenta en la app.
- La fecha de creación no está disponible en SAF ni en `dart:io` para todas las
  rutas; la app muestra “No disponible” en vez de inventarla.
- El selector de documentos y la hoja de compartir de iOS no se pueden
  automatizar dentro del simulador; las operaciones equivalentes en el sandbox
  sí se prueban con los casos IG/IJ. La interacción con esos selectores queda
  como prueba manual.
- Algunos proveedores de documentos en la nube no permiten escribir o
  renombrar; la app informa “operación no permitida” y sugiere importar al
  espacio privado.
- El emulador de Android no se usa: las pruebas se hacen en un celular físico
  por USB (lección de la Práctica 3).

---

## Evidencias

Las capturas se organizan por sistema y app:

- `docs/img/android/gestor/01-inicio-guinda.png` … `09-modo-oscuro.png`
- `docs/img/android/juego/01-inicio.png` … `09-laboratorio-contrarreloj.png`
- `docs/img/ios/gestor/01-inicio-guinda.png` … `09-modo-oscuro.png`
- `docs/img/ios/juego/01-inicio.png` … `08-ajustes-tema-azul.png`

Cada archivo se nombra al momento de tomarlo y se describe en
[`docs/pruebas.md`](docs/pruebas.md). No se modificó la interfaz después de las
capturas; cualquier diferencia se documenta en “Problemas conocidos”.

---

## Conclusiones

Antes de esta práctica pensaba que “leer archivos” era una sola operación.
Al implementar ambas apps entendí que en Android y iOS el acceso es una
**concesión explícita del usuario**: SAF y los security-scoped bookmarks no son
un detalle, son el corazón del diseño. También aprendí que guardar no termina
en `writeAsString`: hace falta escritura atómica, checksum, validación y un
mensaje claro cuando el archivo está dañado, porque el usuario no debería perder
las demás partidas por un error ajeno. Me sorprendió que el mismo código
Flutter pueda comportarse distinto según quién es el proveedor de documentos;
por eso la app distingue entre “no permitido”, “no disponible” y “error real”,
en lugar de mostrar un mensaje genérico.

---

## Referencias (APA)

Flutter. (s. f.). *Flutter documentation*. https://docs.flutter.dev/

Android Developers. (s. f.). *Storage Access Framework*. https://developer.android.com/guide/topics/providers/document-provider

Android Developers. (s. f.). *Scoped storage*. https://developer.android.com/training/data-storage

Apple. (s. f.). *Document picker*. https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller

Apple. (s. f.). *FileManager*. https://developer.apple.com/documentation/foundation/filemanager

Kotlin. (s. f.). *Kotlin Multiplatform*. https://kotlinlang.org/docs/multiplatform.html

Dart. (s. f.). *dart:io library*. https://api.dart.dev/stable/dart-io/dart-io-library.html

Material Design. (s. f.). *Material 3*. https://m3.material.io/
