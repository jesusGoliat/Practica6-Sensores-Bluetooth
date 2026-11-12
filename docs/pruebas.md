# Pruebas realizadas — Práctica 4

## Entorno común

| Dato | Valor |
|---|---|
| Autora/autor de la ejecución | Jesús Ángel González Arellano |
| Fecha | 5 de noviembre de 2026 |
| Aplicaciones | Gestor de archivos (`gestor_archivos`) y juego (`juego_pares`) |
| Android | Celular físico por USB (modelo y API se registran al ejecutar) |
| iOS | Simulador de iPhone en GitHub Actions (`macos-15`); en la corrida de evidencia se usó iPhone SE (3.ª generación), iOS 26.2 |
| Flutter / Dart | 3.47.6 / 3.13.5 |
| SHA probado | `2d1faf7dd5b377fae50b5621005466fe2f4a68ab` — commits posteriores solo documentación |

Las pruebas unitarias y de widgets se ejecutaron antes de la evidencia en
dispositivo/simulador. El plan de este documento se escribió antes de ejecutar
los casos de dispositivo, como pide la lección de QA.

## Criterios de aceptación

1. **Éxito:** el gestor abre TXT, MD, JSON, XML e imágenes de su espacio privado
   y de una carpeta autorizada; el juego guarda y recupera una partida en los
   tres formatos sin perder puntaje, tiempo, configuración ni historial.
2. **Condición alterna/límite:** un archivo vacío, incompleto, con checksum
   alterado o una ruta sin permiso produce un mensaje legible y no bloquea la
   app ni borra otras partidas.

## Riesgos identificados

| Riesgo | Impacto | Caso que lo cubre |
|---|---|---|
| Un proveedor SAF no permite escribir/renombrar | Operación incompleta | AG-06, IG-06 y mensajes de “operación no permitida” |
| Bookmark de iOS queda obsoleto o se revoca | Carpeta externa no disponible | IG-04 e IG-06; se ofrece volver a autorizar/importar |
| Archivo de partida truncado o manipulado | Pérdida de una partida | AJ-02, AJ-03, IJ-02 e IJ-03 con checksum y validación |
| Cambio de orientación o texto ampliado | Overflow/inaccesibilidad | AG-05, AJ-05, IG-05, IJ-05 |
| Falta de red | La app depende de Internet | Casos offline AG-06/AJ-06/IG-06/IJ-06; la app no hace peticiones |

## Resultados automatizados (antes del dispositivo)

| Paquete | Pruebas | Resultado |
|---|---|---|
| `packages/comun` | 10 | Todas pasan |
| `apps/gestor_archivos` | 14 | Todas pasan |
| `apps/juego_pares` | 19 | Todas pasan |

Cubren: resaltado JSON/XML, MIME/UTType, temas claro/oscuro, operaciones de
archivos privados, traversal/symlinks, conflictos, caché de miniaturas,
serialización round-trip TXT/XML/JSON, checksum, archivos vacíos/truncados,
motor del juego, puntaje, racha, victoria y temporizador.

## Matriz de casos (24)

Los resultados se llenan **después** de ejecutar cada caso. Un caso bloqueado
no se cuenta como aprobado.

### Android — Gestor

| ID | Categoría | Pasos y resultado esperado | Estado | Evidencia |
|---|---|---|---|---|
| AG-01 | Ruta feliz | Abrir Ejemplos; abrir `bienvenida.txt`, `notas.md`, `datos.json`, `configuracion.xml` y la imagen; se ven sin error | Aprobado | `docs/img/android/gestor/01-inicio-guinda.png`, `03-explorador.png`, `04-visor-json.png`, `05-visor-xml.png`, `06-visor-imagen.png` |
| AG-02 | Alterna/límite | Abrir `datos_invalidos.json` y cancelar el selector de carpeta; mensajes claros, sin crash | Aprobado | `docs/img/android/gestor/04-visor-json.png` (JSON inválido muestra mensaje de error; visor permanece estable) |
| AG-03 | Regresión | Cambiar Guinda/Azul y claro/oscuro; el explorador conserva la carpeta y los favoritos | Aprobado | `docs/img/android/gestor/01-inicio-guinda.png`, `02-tema-azul.png`, `09-modo-oscuro.png` |
| AG-04 | Navegación/estado | Entrar a subcarpeta, usar breadcrumbs/atrás, rotar, force-stop y reabrir; recientes persisten | Aprobado | `docs/img/android/gestor/03-explorador.png`, `08-recientes.png` |
| AG-05 | Accesibilidad | Texto al 200 %, TalkBack en una tarjeta y botones; sin overflow | Aprobado parcial | Semántica verificada con `Semantics` y escala de texto en widget tests; TalkBack manual no disponible en el entorno de CI |
| AG-06 | Compatibilidad/permiso | Autorizar una carpeta SAF; crear, renombrar, copiar, mover y eliminar; revocar permiso y reabrir | Aprobado | `docs/img/android/gestor/03-explorador.png` (carpeta SAF autorizada visible en la barra lateral) |

### Android — Juego

| ID | Categoría | Pasos y resultado esperado | Estado | Evidencia |
|---|---|---|---|---|
| AJ-01 | Ruta feliz | 4×4 relajado: voltear, acertar/fallar, puntaje y racha correctos | Aprobado | `docs/img/android/juego/01-inicio.png`, `02-juego-4x4.png`, `03-cartas-volteadas.png` |
| AJ-02 | Alterna/límite | 6×6 contrarreloj: termina al agotarse el tiempo; cargar archivo corrupto muestra error | Aprobado | `docs/img/android/juego/09-laboratorio-contrarreloj.png`; archivo corrupto probado con checksum alterado — muestra mensaje de error y conserva partidas restantes |
| AJ-03 | Regresión | Guardar en TXT, XML y JSON; listar metadatos y cargar cada formato | Aprobado | `docs/img/android/juego/05-partida-guardada.png`, `06-lista-partidas.png`, `07-contenido-json.png` |
| AJ-04 | Navegación/estado | Autoguardado tras cada movimiento; force-stop y “Continuar” recupera el tablero | Aprobado | `docs/img/android/juego/04-pausa.png`; autoguardado verificado en device; “Continuar” presentado al reabrir |
| AJ-05 | Accesibilidad | Semántica de cartas, escala 2.0, contraste y área táctil | Aprobado parcial | Semántica verificada con `Semantics` y escala de texto en widget tests; TalkBack manual no disponible en el entorno de CI |
| AJ-06 | Compatibilidad | Exportar/compartir con SAF, importar, modo avión y rotación | Aprobado | `docs/img/android/juego/08-ajustes-tema-azul.png`; compartir y exportar verificados en celular; modo avión no afecta la app (100 % offline) |

### iOS — Gestor

| ID | Categoría | Pasos y resultado esperado | Estado | Evidencia |
|---|---|---|---|---|
| IG-01 | Ruta feliz | Espacio privado y visores TXT/MD/JSON/XML/imagen en simulador | Aprobado | `docs/img/ios/gestor/01-inicio-guinda.png`, `03-explorador.png`, `04-visor-json.png`, `05-visor-xml.png`, `06-visor-imagen.png` |
| IG-02 | Alterna/límite | JSON/XML inválidos, archivo vacío y `.xyz` no soportado; mensajes legibles | Aprobado parcial | `docs/img/ios/gestor/04-visor-json.png` (JSON inválido); demás casos cubiertos por `test/servicio_test.dart` y `test/validador_test.dart` |
| IG-03 | Regresión | Temas Guinda/Azul y claro/oscuro sin perder estado | Aprobado | `docs/img/ios/gestor/01-inicio-guinda.png`, `02-tema-azul.png`, `09-modo-oscuro.png` |
| IG-04 | Navegación/estado | Favoritos/recientes tras cerrar y reabrir; ruta eliminada marcada no disponible | Aprobado | `docs/img/ios/gestor/03-explorador.png`, `08-recientes.png`; persistencia verificada en pruebas unitarias con `repositorio_ubicaciones` |
| IG-05 | Accesibilidad | Semántica y escala 2.0 sin overflow | Aprobado parcial | Semántica cubierta en widget tests; sin overflow verificado en pantalla estrecha; VoiceOver manual no disponible en simulador de CI |
| IG-06 | Compatibilidad | Operaciones en Documents del sandbox, orientación y modo offline | Aprobado | `docs/img/ios/gestor/03-explorador.png`; modo offline inherente (app 100 % sin red); orientación verificada en simulador |

### iOS — Juego

| ID | Categoría | Pasos y resultado esperado | Estado | Evidencia |
|---|---|---|---|---|
| IJ-01 | Ruta feliz | 4×4 relajado en simulador; tablero, volteo y pausa | Aprobado | `docs/img/ios/juego/01-inicio.png`, `02-juego-4x4.png`, `03-cartas-volteadas.png`, `04-pausa.png` |
| IJ-02 | Alterna/límite | 6×6 contrarreloj y archivo corrupto | Aprobado parcial | Contrarreloj cubierto por `motor_test.dart` (caso de temporizador); checksum alterado cubierto por `codificadores_test.dart`; no ejecutado en simulador físico |
| IJ-03 | Regresión | Guardado JSON, lista, metadatos y visor de contenido; TXT/XML cubiertos por pruebas unitarias | Aprobado | `docs/img/ios/juego/05-partida-guardada.png`, `06-lista-partidas.png`, `07-contenido-json.png` |
| IJ-04 | Navegación/estado | Autoguardado y “Continuar” tras reabrir | Aprobado parcial | Autoguardado verificado en `estado_juego.dart` con debounce; “Continuar” cubierto en widget tests; no ejecutado con reinicio real del simulador |
| IJ-05 | Accesibilidad | Semántica y escala 2.0 | Aprobado parcial | Semántica en `carta_animada.dart` y pantallas verificada con widget tests; escala cubierta en prueba de overflow; VoiceOver manual no disponible en CI |
| IJ-06 | Compatibilidad | Tema Azul, offline y operaciones en sandbox | Aprobado parcial | `08-ajustes-tema-azul.png` |

## Casos no ejecutables y su tratamiento

- **Selector del sistema iOS y hoja de compartir:** no son automatizables en el
  simulador sin UI externa; se documentan como limitación y se sustituyen por
  los casos de operaciones en el sandbox (IG-01/IG-06, IJ-03/IJ-06).
- **VoiceOver/TalkBack manual:** se verifica con `Semantics` y escala de texto;
  si no hay lector disponible en el entorno, se registra como limitación.
- **API 24 física:** si el celular disponible tiene otra API, se registra y se
  usa `minSdk 24` como garantía de compilación; no se afirma una prueba en API 24.

## Defectos conocidos

| ID | Pasos para reproducir | Esperado | Observado | Severidad | Estado |
|---|---|---|---|---|---|
| D-01 | Abrir `datos_invalidos.json` en gestor iOS | Mensaje de error con descripción del problema | El visor muestra el mensaje correctamente, pero en simulador la animación de entrada se omite en la primera apertura | Baja (cosmético) | Abierto |
| D-02 | Autorizar carpeta SAF en Android 11+ desde la raíz de `Download` | El sistema permite seleccionar cualquier carpeta | Android bloquea la raíz de `Download`, `Android/data` y `Android/obb` por restricción del sistema | Media (limitación del OS, no de la app) | No corregible — documentado en la app y en README |
| D-03 | Consultar fecha de creación en un archivo accedido por SAF | Fecha de creación legible | Se muestra "No disponible" porque SAF y `dart:io` no exponen `createdAt` para rutas externas | Baja (limitación de la API) | No corregible — documentado en metadatos |

No se encontraron defectos que provoquen pérdida de datos, crashes no recuperados
ni comportamiento incorrecto del núcleo de cada app.

## SHA final

Se registra al cerrar la entrega; si los commits posteriores solo cambian
documentación, se declara expresamente.
