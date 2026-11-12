# Pares IPN — Juego con gestión de archivos

Memorama original del campus para Android e iOS, 100 % offline.

## Funciones

- Niveles Campus 4×4 (8 parejas) y Laboratorio 6×6 (18 parejas).
- Modos Relajado y Contrarreloj (90 s / 180 s).
- Categorías Ciencias, Ingeniería, Cómputo e IPN; completar una categoría da
  150 puntos extra.
- Puntaje por pareja y racha, penalización por fallo, bonificación final y
  progreso persistente (mejor puntaje y partidas jugadas).
- Efectos de volteo, pulso y confeti; sonidos WAV generados localmente con
  interruptor.
- Guardado/carga en **TXT, XML y JSON**, formato elegido por el usuario.
- Estado, puntaje, tiempo, configuración e historial de movimientos dentro del
  archivo; etiquetas, lista con metadatos, exportar, compartir e importar.
- Autoguardado tras cada movimiento y al pasar a segundo plano; “Continuar” al
  abrir la app.
- Validación de archivos vacíos/incompletos/corruptos con checksum FNV-1a, sin
  borrar las demás partidas.
- Temas Guinda/Azul, claro/oscuro automático y diseño responsivo.

## Ejecutar

```bash
flutter pub get
flutter test
flutter run                 # celular Android por USB o simulador iOS
flutter build apk --release
```

iOS requiere macOS con Xcode 16+:
```bash
cd ios && pod install && cd ..   # solo si el entorno lo requiere
flutter run -d "iPhone 16"
```

## Formato de los archivos

- **JSON:** objeto versionado con `tablero`, `movimientos`, `configuracion` y
  `checksum`.
- **XML:** raíz `<partida schema="memorama-ipn" version="1">` con elementos para
  tablero, movimientos y configuración.
- **TXT:** líneas `clave=valor`, sección de tablero/movimientos separada por `|`
  y línea final `FIN`.

Los archivos se guardan por defecto en `Documentos/partidas` del contenedor
privado de la app.
