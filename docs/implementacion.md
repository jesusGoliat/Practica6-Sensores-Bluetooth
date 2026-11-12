# Implementación técnica — Práctica 4

## 1. Arquitectura compartida

```text
packages/comun/                 Temas Guinda/Azul, textos, MIME/UTType,
                                resaltado JSON/XML, breadcrumbs y diálogos
packages/selector_carpetas_ios/ Plugin Swift: UIDocumentPicker + bookmark
apps/gestor_archivos/           App 1 (Android + iOS)
apps/juego_pares/               App 2 (Android + iOS)
```

Las dos apps son proyectos Flutter independientes, cada uno con sus carpetas
`android/` e `ios/` y su propio `applicationId`:

- `mx.ipn.escom.p4.gestorarchivos`
- `mx.ipn.escom.p4.juegopares`

Así se pueden instalar juntas en el mismo teléfono. `packages/comun` evita que
los textos, los temas y el resaltado se dupliquen (lección de la Tarea 2).

## 2. Gestor de archivos: acceso por plataforma

### Espacio privado

`path_provider` entrega el directorio de documentos de la app. `dart:io` hace
listar, leer, escribir, copiar, mover, renombrar y eliminar. Es la zona donde
todas las operaciones están garantizadas.

### Android: Storage Access Framework

Se usa el paquete `saf` (SAF, `DocumentsContract` por debajo):

- `pickDirectory(persistablePermission: true)` abre `ACTION_OPEN_DOCUMENT_TREE`
  y conserva el permiso entre reinicios.
- `list`, `stat`, `readFileBytes`, `writeFileBytes`, `mkdirp`, `rename`,
  `copyTo`, `moveTo` y `delete` operan sobre el `content://` autorizado.
- No se declara `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` ni
  `MANAGE_EXTERNAL_STORAGE`; el acceso nace del selector del sistema.
- El `treeUri` se guarda en `shared_preferences`. Si el permiso se revoca, la
  raíz se marca como no disponible y se ofrece volver a autorizar o importar.
- Límites del sistema que se documentan: Android 11+ no permite autorizar la
  raíz del almacenamiento, `Download` raíz, `Android/data` ni `Android/obb`.
  Algunos proveedores de nube no funcionan offline.

### iOS: sandbox + security-scoped bookmarks

El plugin local `selector_carpetas_ios` presenta
`UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)`.
Al elegir una carpeta:

1. `startAccessingSecurityScopedResource()`.
2. `bookmarkData(options: [.minimalBookmark])` y se devuelve el token Base64.
3. El token se guarda en `shared_preferences`.
4. En el siguiente arranque se resuelve con
   `URL(resolvingBookmarkData:options: [.withoutUI])`; si está obsoleto se
   regenera y si no resuelve se marca “permiso revocado”.
5. `dart:io` opera sobre la ruta mientras el scope está abierto.

`Info.plist` activa `UIFileSharingEnabled` y
`LSSupportsOpeningDocumentsInPlace` para que la carpeta Documents de la app sea
visible en la app Archivos.

### Validación y errores

- `ValidadorRutas` rechaza `..`, separadores, nombres reservados y rutas fuera
  de la raíz; resuelve symlinks antes de autorizar una escritura.
- `ErrorArchivo` traduce `FileSystemException`, `SafPermissionException`,
  `SafNotFoundException`, `SafAlreadyExistsException` y `SafIoException` a
  mensajes en español. `ENOSPC` se reporta como espacio insuficiente.
- Las acciones destructivas y las sobrescrituras piden confirmación.
- Las operaciones no admitidas por el proveedor se informan sin bloquear.

### Metadatos, favoritos, recientes y caché

- Metadatos: nombre, tamaño, modificación, creación (o “No disponible”), MIME y
  UTType. En SAF la fecha de creación no existe; se muestra “No disponible”.
- Favoritos y recientes: `shared_preferences` con referencias (origen, URI/ruta,
  raíz y token), no rutas absolutas dependientes del contenedor. Se revalidan
  al iniciar.
- Miniaturas: `CacheMiniaturas` decodifica en un isolate, reduce a 320 px,
  guarda JPEG en la caché temporal con clave SHA-1 (ruta + tamaño + mtime) y
  poda por LRU (40 MB / 300 archivos).

## 3. Juego: modelo y serialización

El modelo canónico `EstadoPartida` guarda:

- tablero, estados de las cartas y semilla;
- puntaje, tiempo, racha y mejor racha;
- nivel (Campus 4×4 / Laboratorio 6×6) y modo (Relajado / Contrarreloj);
- configuración (nombre, sonido, animaciones, formato, tema);
- historial de movimientos (índices, símbolos, acierto, delta y tiempo);
- fechas, etiqueta y versión del esquema.

Los tres codificadores parten del mismo `aJson()` y agregan un **checksum
FNV-1a de 32 bits**:

- **JSON:** objeto con sangría y campo `checksum`.
- **XML:** `<partida schema="memorama-ipn" version="1">` con `<tablero>`,
  `<movimientos>`, `<configuracion>` y `<checksum>`.
- **TXT:** secciones `clave=valor`, `tablero` y `movimientos` separados por `|`,
  línea final `FIN`, escape con `Uri.encodeComponent`.

Al leer, cada codificador reconstruye el estado, ejecuta `ValidadorPartida`
(versión, tamaño, parejas, índices, puntaje, estado coherente) y compara el
checksum. Un archivo vacío, truncado o alterado produce un `ErrorPartida`
legible; nunca se borran las demás partidas.

El repositorio escribe a un archivo temporal, hace `flush` y renombra
(escritura atómica). El autoguardado se escribe después de cada movimiento con
un pequeño debounce y al pasar la app a segundo plano; al abrir se ofrece
“Continuar”. Al terminar se guarda una partida final en el formato preferido.

## 4. Pruebas y evidencias

- `flutter test` cubre el núcleo, los servicios privados, el motor, la
  serialización y los widgets.
- `integration_test` + `flutter drive` recorre los flujos principales y captura
  screenshots reales en el simulador de iOS desde GitHub Actions.
- En Android las capturas se toman con `adb exec-out screencap` en el celular
  físico; el emulador no se usa.

## 5. Decisiones y límites

- Se eligió Flutter para compartir código y porque el PDF lo permite.
- En Android se usa SAF; en iOS, document picker y bookmarks. No hay acceso
  global al sistema de archivos.
- El selector de iOS y la hoja de compartir nativa no se automatizan en el
  simulador; se documentan como limitación y se cubren las operaciones
  equivalentes dentro del sandbox.
- La app es 100 % offline: no hay llamadas de red ni dependencias de servicios.
