# Archivos IPN — Gestor de archivos multiplataforma

Aplicación Flutter para Android e iOS que funciona 100 % offline.

## Funciones

- Exploración del espacio privado y de carpetas autorizadas con el selector del
  sistema (SAF en Android, document picker y security-scoped bookmark en iOS).
- Breadcrumbs, vista de lista/cuadrícula, orden por nombre/fecha/tamaño, vista
  de árbol y búsqueda local de la carpeta actual.
- Visor de texto/Markdown, JSON y XML con formato y resaltado; imágenes con
  zoom, paneo y rotación.
- Metadatos con MIME/UTType y “No disponible” cuando el sistema no los expone.
- Favoritos y recientes persistentes, caché de miniaturas con poda LRU.
- Crear carpeta, copiar, mover, renombrar, eliminar, compartir, exportar y abrir
  con otra aplicación. Confirmación para acciones destructivas y conflictos.
- Temas Guinda IPN y Azul ESCOM, claro/oscuro automático y diseño responsivo.

## Ejecutar

```bash
flutter pub get
flutter test
flutter run                 # celular Android por USB o simulador iOS
flutter build apk --release # APK release
```

Para iOS se necesita macOS con Xcode 16+:
```bash
cd ios && pod install && cd ..   # solo si el entorno lo requiere
flutter run -d "iPhone 16"
```

## Estructura

- `lib/dominio/`: modelos, errores y validación de rutas.
- `lib/datos/`: servicio privado, SAF, iOS, preferencias, caché, semilla,
  acciones nativas y estado del explorador.
- `lib/presentacion/`: pantallas, visores, diálogos y widgets.
- `test/`: pruebas de servicios, validación y widgets.
- `integration_test/`: recorrido con capturas para el simulador iOS.

## Limitaciones

- Android 11+ restringe ciertas raíces de SAF; el selector del sistema es la
  única vía de acceso y la app lo explica.
- La fecha de creación no está disponible en todas las rutas y se muestra
  “No disponible”.
- El selector y la hoja de compartir de iOS requieren interacción manual; las
  operaciones dentro del sandbox sí están cubiertas por las pruebas.
