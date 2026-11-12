# Plan y registro de pruebas — Práctica 6

> Documento escrito **antes** de ejecutar los casos. Todo resultado queda en
> `pendiente` hasta que se ejecute en dispositivo real. Un caso bloqueado no se
> cuenta como aprobado. Estados posibles: `pendiente`, `aprobado`, `fallido`,
> `bloqueado`, `no aplica`.

## Entorno

| Dato | Valor |
|---|---|
| Autor de la ejecución | Jesús Ángel González Arellano |
| Fecha de ejecución | `<por llenar>` |
| Aplicaciones | `gestor_archivos` (Archivos IPN) y `juego_pares` (Pares IPN) |
| Teléfono 1 (propio) | Modelo `<por llenar>` · Android `<por llenar>` · API `<por llenar>` |
| Teléfono 2 (prestado) | Modelo `<por llenar>` · Android `<por llenar>` · API `<por llenar>` |
| iOS | Simulador en Codemagic (sin Bluetooth ni sensores): modelo y versión `<por llenar>` |
| Flutter / Dart | 3.47.6 / 3.13.5 |
| Build probado | APK `<por llenar>` · SHA `<por llenar>` · versión de app `<por llenar>` |
| Wi-Fi / datos | Teléfono B (WEB): apagados; teléfono A (WEB): con Internet |
| Emulador de Android | **No se usa** (laptop con poca memoria); solo teléfonos físicos por USB |

Roles de los dos teléfonos: T1 = teléfono propio; T2 = teléfono prestado. En
cada caso se indica quién es anfitrión/periférico y quién invitado/central.

## Criterios de aceptación

| ID | Ejercicio | Criterio observable |
|---|---|---|
| CA-01 | Sensores | Acelerómetro y giroscopio muestran valor x/y/z, unidad, instante y estado; la insignia distingue lectura FÍSICA de SIMULADA |
| CA-02 | Sensores | Si un sensor falta se informa «ausente» sin cierre de la app; las lecturas disparan una acción (sacudir refresca; inclinar/girar controla el juego) |
| CA-03 | Sensores | Al ir a segundo plano o salir de la pantalla las suscripciones se cancelan y se reanudan al volver; queda registro en la bitácora |
| CA-04 | Biometría | Eliminar y Bóveda piden autenticación; sin biometría se ofrece la credencial del dispositivo |
| CA-05 | Biometría | Cancelar, fallar o no tener enrolamiento/bloqueo nunca ejecuta la acción protegida |
| CA-06 | Permisos | Permiso denegado, permanente, revocado o Bluetooth apagado muestran explicación y camino de recuperación sin cierre |
| CA-07 | Juego BT | Dos teléfonos inician sesión por BLE (sin Internet), con roles, turno y tablero idénticos en ambos |
| CA-08 | Juego BT | Un mensaje duplicado no repite una jugada; una jugada fuera de turno o inválida se rechaza |
| CA-09 | Juego BT | Desconexión, reconexión y abandono se informan en ambos extremos; al reiniciar se reanuda o se reporta que terminó |
| CA-10 | Archivos | TXT, JSON, XML y JPG llegan íntegros (SHA-256 igual) con progreso, y un archivo multibloque (≈300 KB) también |
| CA-11 | Archivos | Integridad fallida, cancelación, desconexión, rechazo o reinicio nunca dejan un archivo parcial marcado como completado |
| CA-12 | Archivos | Se rechazan tamaño > 512 KiB, nombre inseguro, tipo no permitido y cola > 5 |
| CA-13 | Web | B, sin Wi-Fi ni datos, obtiene por Bluetooth la respuesta HTTPS de A y ve estado, tiempo y rol |
| CA-14 | Web | Dominios no permitidos, IP privadas, redirecciones inseguras, tamaño, duración y frecuencia se limitan con error legible |
| CA-15 | Web | Se distingue RED de CACHÉ con fecha; duplicados de petición no repiten la salida a Internet; atrás/adelante/favoritos funcionan |
| CA-16 | Regresión | Las funciones de la Práctica 4 siguen igual |
| CA-17 | iOS | En el simulador las apps abren y degradan con mensajes donde falta hardware |

## Riesgos

| ID | Riesgo | Impacto | Caso que lo cubre |
|---|---|---|---|
| R-01 | El teléfono no tiene giroscopio/acelerómetro | Función inutilizable o cierre | SEN-03, IOS-04 |
| R-02 | Suscripciones activas en segundo plano | Gasto de batería, lecturas obsoletas | SEN-04, SEN-05 |
| R-03 | Valores extremos disparan acciones repetidas | Comportamiento errático | SEN-06 |
| R-04 | Frecuencia de muestreo excesiva | Batería y rendimiento | SEN-10 |
| R-05 | Acción sensible ejecutada sin autenticar | Borrado no autorizado | BIO-02, BIO-05 |
| R-06 | Permiso denegado o revocado a mitad de sesión | Cierre o estado inconsistente | PER-02, PER-03 |
| R-07 | Mensaje duplicado (reenvío BLE) reaplica jugada/petición | Estado corrupto, doble tráfico | JUE-03, WEB-08 |
| R-08 | Reinicio durante sesión/transferencia | Estado huérfano o archivo parcial «completado» | JUE-09, ARC-13 |
| R-09 | Fragmentación y MTU distintos entre teléfonos | Mensajes truncados | ARC-05 |
| R-10 | Corrupción o pérdida de bloques | Archivo dañado aceptado | ARC-06, ARC-09 |
| R-11 | El dispositivo A actúa como proxy hacia destinos internos | SSRF a la red local | WEB-04, WEB-05, WEB-06 |
| R-12 | Texto ampliado o lector de pantalla | Pantallas inaccesibles | ACC-01…04 |
| R-13 | iOS sin hardware en simulador | No se puede verificar | IOS-03, IOS-04; pares iOS declarados no verificados |

## Matriz de pruebas

Cada caso: ID, criterio/riesgo, plataforma, dispositivo/rol, precondiciones,
pasos, esperado, **obtenido**, estado y evidencia. Autor y fecha de ejecución,
SHA y versión de app: ver «Entorno».


### Sensores (SEN)

Gestor y juego; teléfono propio salvo indicación.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| SEN-01 | CA-01 | Android | Teléfono 1, gestor | Sensores físicos presentes | 1. Abrir Ajustes → Sensores.<br>2. Mover el teléfono.<br>3. Observar el panel del acelerómetro. | x/y/z cambian, unidad `m/s²`, hora de la lectura, estado `escuchando`, insignia FÍSICA | pendiente | pendiente | `docs/img/android/01-SEN01-acelerometro-fisico.png` |
| SEN-02 | CA-01 | Android | Teléfono 1, gestor | Sensores físicos presentes | 1. Abrir la pantalla de sensores.<br>2. Girar el teléfono sobre sus ejes.<br>3. Observar el panel del giroscopio. | x/y/z en `rad/s`, instante y estado visibles, insignia FÍSICA | pendiente | pendiente | `docs/img/android/02-SEN02-giroscopio-fisico.png` |
| SEN-03 | CA-02 / R-01 | Android | Teléfono 1, juego | Activar fuente simulada «ausente» en Diagnóstico | 1. Abrir sensores con fuente ausente.<br>2. Activar «Control por movimiento». | Estado `ausente` con mensaje legible; sin cierre; el juego sigue jugable por toque | pendiente | pendiente | `docs/img/android/03-SEN03-sensor-ausente.png` |
| SEN-04 | CA-03 / R-02 | Android | Teléfono 1, gestor | Pantalla de sensores escuchando | 1. Pulsar Inicio (segundo plano) 10 s.<br>2. Volver a la app.<br>3. Revisar la bitácora. | Bitácora registra pausa y reanudación; no llegan lecturas en segundo plano; tras volver el estado es `escuchando` | pendiente | pendiente | `docs/img/android/04-SEN04-pausa-reanuda.png` |
| SEN-05 | CA-03 / R-02 | Android | Teléfono 1, gestor | Pantalla de sensores escuchando | 1. Salir de la pantalla con Atrás.<br>2. Revisar la bitácora/contador de suscripciones activas. | Suscripciones en 0 (`inactivo`); no hay lecturas tras salir | pendiente | pendiente | `docs/img/android/05-SEN05-cancela-suscripcion.png` |
| SEN-06 | CA-01 / R-03 | Android | Teléfono 1, gestor | Fuente simulada con valores extremos | 1. Elegir escenario «Extremo» (±160 m/s², ±35 rad/s).<br>2. Observar panel y detectores. | Valores mostrados sin overflow, insignia SIMULADA; sin excepciones; acción activada una sola vez por enfriamiento | pendiente | pendiente | `docs/img/android/06-SEN06-valores-extremos.png` |
| SEN-07 | CA-01 | Android | Teléfono 1, juego | Fuente simulada y fuente física disponibles | 1. Alternar entre fuente física y simulada.<br>2. Comparar insignias. | La insignia distingue FÍSICA de SIMULADA; no se mezclan lecturas | pendiente | pendiente | `docs/img/android/07-SEN07-simulada-vs-fisica.png` |
| SEN-08 | CA-02 | Android | Teléfono 1, gestor | Carpeta con archivos | 1. Crear un archivo desde otro medio o editar.<br>2. Sacudir el teléfono en el explorador. | El listado se refresca una vez por sacudida (enfriamiento 800 ms) | pendiente | pendiente | `docs/img/android/08-SEN08-sacudir-refresca.png` |
| SEN-09 | CA-02 | Android | Teléfono 1, juego | «Control por movimiento» activo | 1. Inclinar a la derecha/abajo.<br>2. Girar la muñeca rápido. | El cursor se mueve por inclinación y el giro voltea la carta del cursor | pendiente | pendiente | `docs/img/android/09-SEN09-inclinar-girar-juego.png` |
| SEN-10 | R-04 | Android | Teléfono 1, gestor | Registro de lecturas activo | 1. Dejar escuchar 10 s.<br>2. Contar lecturas en la bitácora/contador. | ≈10 lecturas por segundo por sensor (periodo 100 ms), no cientos | pendiente | pendiente | `docs/img/android/10-SEN10-frecuencia.png` |
| SEN-11 | CA-03 | Android | Teléfono 1, gestor | Sin lecturas (fuente simulada que no emite) | 1. Esperar más de 2 s. | Estado `sinDatos` con aviso; se recupera al volver a emitir | pendiente | pendiente | `docs/img/android/11-SEN11-sin-datos.png` |

### Biometría (BIO)

Solo gestor de archivos.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| BIO-01 | CA-04 | Android | Teléfono 1, gestor | Huella o PIN enrolados | 1. Seleccionar un archivo → Eliminar.<br>2. Autenticar correctamente. | Pide autenticación antes de eliminar; tras éxito elimina | pendiente | pendiente | `docs/img/android/12-BIO01-eliminar-exito.png` |
| BIO-02 | CA-05 / R-05 | Android | Teléfono 1, gestor | Igual | 1. Eliminar → cancelar el diálogo biométrico. | El archivo NO se elimina; mensaje «cancelado» | pendiente | pendiente | `docs/img/android/13-BIO02-eliminar-cancela.png` |
| BIO-03 | CA-05 | Android | Teléfono 1, gestor | Igual | 1. Eliminar → fallar la huella varias veces. | Reintento permitido o bloqueo temporal del sistema; el archivo permanece | pendiente | pendiente | `docs/img/android/14-BIO03-eliminar-falla.png` |
| BIO-04 | CA-04 | Android | Teléfono 1, gestor | Sin huella enrolada, con PIN/patrón | 1. Entrar a la Bóveda. | Se ofrece la credencial del dispositivo; accede tras ingresarla | pendiente | pendiente | `docs/img/android/15-BIO04-boveda-credencial.png` |
| BIO-05 | CA-05 / R-05 | Android | Teléfono 1, gestor | Sin ningún bloqueo de pantalla (o sin enrolamiento) | 1. Eliminar y entrar a Bóveda. | Acción bloqueada con explicación para configurar un bloqueo; sin acceso | pendiente | pendiente | `docs/img/android/16-BIO05-sin-enrolamiento.png` |
| BIO-06 | CA-04 | Android | Teléfono 1, gestor | Bóveda con archivos | 1. Entrar a la Bóveda autenticando.<br>2. Salir y reentrar tras pasar a segundo plano. | Pide autenticación según la política documentada; sin datos visibles antes de autenticar | pendiente | pendiente | `docs/img/android/17-BIO06-boveda-ciclo.png` |

### Permisos (PER)

Estado de Bluetooth y permisos. Registrar la versión de Android.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| PER-01 | CA-06 | Android | Teléfono 1, juego | Permisos no concedidos | 1. Crear partida (anfitrión).<br>2. Denegar el permiso de dispositivos cercanos. | Explicación del motivo y botón para reintentar; sin cierre | pendiente | pendiente | `docs/img/android/18-PER01-denegado.png` |
| PER-02 | CA-06 / R-06 | Android | Teléfono 1, gestor | Denegado dos veces o «No volver a preguntar» | 1. Intentar buscar dispositivos. | Estado «denegado permanentemente» con botón a Ajustes de la app | pendiente | pendiente | `docs/img/android/19-PER02-denegado-permanente.png` |
| PER-03 | CA-06 / R-06 | Android | Teléfono 1, juego | Sesión BLE activa | 1. Revocar el permiso desde Ajustes.<br>2. Volver a la app. | La sesión se cierra con aviso y la app queda estable | pendiente | pendiente | `docs/img/android/20-PER03-revocado.png` |
| PER-04 | CA-06 | Android | Teléfono 1, gestor | Bluetooth apagado | 1. Abrir transferencia.<br>2. Observar el estado. | Mensaje «Bluetooth apagado» con acción para encenderlo; al encenderlo continúa | pendiente | pendiente | `docs/img/android/21-PER04-bt-apagado.png` |
| PER-05 | CA-06 | Android | Teléfono 1 | Versión según dispositivo | 1. Revisar el diálogo de permisos solicitado. | Android 12+: solo Bluetooth cercano (sin ubicación); Android ≤ 11: lo documentado en arquitectura | pendiente | pendiente | `docs/img/android/22-PER05-permisos-version.png` |
| PER-06 | CA-06 | Android | Teléfono 1 | Sin permiso de notificaciones (Android 13+) | 1. Completar una transferencia con la app en primer plano. | La app informa en pantalla; no falla si se deniega el aviso local | pendiente | pendiente | `docs/img/android/23-PER06-notificacion-denegada.png` |

### Partida por Bluetooth (JUE)

Dos teléfonos Android con el juego. A = anfitrión (periférico), B = invitado (central).

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| JUE-01 | CA-07 | Android↔Android | T1 anfitrión, T2 invitado | Permisos y BT activos en ambos | 1. T1: «Crear partida».<br>2. T2: «Unirse» y elegir `P6-juego-XXXX`.<br>3. T1 acepta. | Ambos muestran conectado, roles, turno inicial, tablero idéntico | pendiente | pendiente | `docs/img/android/24-JUE01-inicio-sesion.png` |
| JUE-02 | CA-07 | Android↔Android | T1, T2 | Sesión iniciada | 1. T1 voltea una carta.<br>2. Observar T2.<br>3. T2 juega su turno. | La jugada aparece en el otro extremo; el turno cambia y se ve en ambos | pendiente | pendiente | `docs/img/android/25-JUE02-jugada-sincronizada.png` |
| JUE-03 | CA-08 / R-07 | Android↔Android | T1, T2 | Modo Diagnóstico «Duplicar mensaje» | 1. T1 envía una jugada con duplicado. | T2 aplica la jugada una sola vez, reenvía ACK; puntaje sin cambio extra | pendiente | pendiente | `docs/img/android/26-JUE03-mensaje-duplicado.png` |
| JUE-04 | CA-08 | Android↔Android | T1, T2 | Diagnóstico «Jugar fuera de turno» | 1. T2 envía una jugada en turno de T1. | Rechazada con `ERROR{turno}`; estado sin cambios | pendiente | pendiente | `docs/img/android/27-JUE04-fuera-de-turno.png` |
| JUE-05 | CA-08 | Android↔Android | T1, T2 | Diagnóstico «Jugada inválida» | 1. Enviar índice repetido/fuera de rango. | Rechazada con `ERROR{jugada}`; sin cierre | pendiente | pendiente | `docs/img/android/28-JUE05-jugada-invalida.png` |
| JUE-06 | CA-09 | Android↔Android | T1, T2 | Partida en curso | 1. Apagar Bluetooth en T2. | T1 y T2 muestran «Conexión perdida» y opción de reconectar | pendiente | pendiente | `docs/img/android/29-JUE06-desconexion.png` |
| JUE-07 | CA-09 | Android↔Android | T1, T2 | Tras JUE-06 | 1. Encender BT en T2.<br>2. Pulsar «Reconectar». | Se retoma con `REANUDAR`, mismo tablero y turno; sin jugadas repetidas | pendiente | pendiente | `docs/img/android/30-JUE07-reconexion.png` |
| JUE-08 | CA-09 | Android↔Android | T1, T2 | Partida en curso | 1. T2 pulsa «Abandonar». | T1 ve «El rival abandonó» y el resultado; ambos regresan al menú | pendiente | pendiente | `docs/img/android/31-JUE08-abandonar.png` |
| JUE-09 | CA-09 / R-08 | Android↔Android | T1 | Partida en curso, T2 no regresa | 1. Forzar detención de T1 y reabrir. | Se muestra la partida restaurada para reanudar o aviso «terminó» con el motivo | pendiente | pendiente | `docs/img/android/32-JUE09-fin-persistido.png` |
| JUE-10 | CA-07 | Android↔Android | T1, T2 | Diagnóstico «Versión distinta» | 1. T2 envía `v:2`. | `ERROR{version}` y mensaje ignorado; sesión estable | pendiente | pendiente | `docs/img/android/33-JUE10-version-distinta.png` |
| JUE-11 | CA-07 | Android↔Android | T1, T2 | Partida hasta el final | 1. Terminar todos los pares. | Ambos muestran el mismo ganador y puntajes (`FIN`) | pendiente | pendiente | `docs/img/android/34-JUE11-resultado-final.png` |

### Transferencia de archivos (ARC)

Gestor, dos teléfonos Android. Emisor = central (B), receptor = periférico (A). Archivos de muestra: `nota.txt`, `datos.json`, `config.xml`, `foto.jpg` (≈30 KB) y `grande.txt` (≈300 KB).

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| ARC-01 | CA-10 | Android↔Android | T1 receptor, T2 emisor | BLE listo | 1. T1: «Recibir». T2: buscar y elegir T1.<br>2. T2 elige `nota.txt`; T1 acepta.<br>3. Esperar fin. | Progreso visible; `recibidos/nota.txt` idéntico (SHA-256 igual); historial «completado» | pendiente | pendiente | `docs/img/android/35-ARC01-txt.png` |
| ARC-02 | CA-10 | Android↔Android | T1, T2 | Igual | 1. Repetir con `datos.json`. | Completado; el visor JSON lo abre | pendiente | pendiente | `docs/img/android/36-ARC02-json.png` |
| ARC-03 | CA-10 | Android↔Android | T1, T2 | Igual | 1. Repetir con `config.xml`. | Completado; el visor XML lo abre | pendiente | pendiente | `docs/img/android/37-ARC03-xml.png` |
| ARC-04 | CA-10 | Android↔Android | T1, T2 | Igual | 1. Repetir con `foto.jpg`. | Completado; la imagen se abre | pendiente | pendiente | `docs/img/android/38-ARC04-jpg.png` |
| ARC-05 | CA-10 / R-09 | Android↔Android | T1, T2 | `grande.txt` ≈300 KB (≈150 bloques) | 1. Enviar y aceptar.<br>2. Observar progreso y bloques. | Progreso 0–100 % creciente, múltiples bloques con ACK, SHA-256 coincide | pendiente | pendiente | `docs/img/android/39-ARC05-multibloque-300kb.png` |
| ARC-06 | CA-11 / R-10 | Android↔Android | T1, T2 | Diagnóstico «Alterar un bloque» en emisor | 1. Enviar `nota.txt`. | Receptor detecta SHA-256 distinto, borra temporal, estado «fallido», no aparece en `recibidos/` | pendiente | pendiente | `docs/img/android/40-ARC06-integridad-falla.png` |
| ARC-07 | CA-11 | Android↔Android | T1, T2 | `grande.txt` | 1. T2 pulsa «Cancelar» a mitad. | Ambos «cancelado»; sin archivo parcial en `recibidos/` | pendiente | pendiente | `docs/img/android/41-ARC07-cancela-emisor.png` |
| ARC-08 | CA-11 | Android↔Android | T1, T2 | `grande.txt` | 1. T1 cancela a mitad. | Emisor ve «cancelado por el receptor»; sin parcial | pendiente | pendiente | `docs/img/android/42-ARC08-cancela-receptor.png` |
| ARC-09 | CA-11 / R-10 | Android↔Android | T1, T2 | `grande.txt` | 1. Apagar BT en T2 a mitad. | Ambos «fallido: conexión perdida»; parcial borrado; nunca «completado» | pendiente | pendiente | `docs/img/android/43-ARC09-desconexion.png` |
| ARC-10 | CA-11 | Android↔Android | T1, T2 | Oferta enviada | 1. T1 pulsa «Rechazar». | Emisor ve «rechazado»; no se transfieren bloques | pendiente | pendiente | `docs/img/android/44-ARC10-receptor-rechaza.png` |
| ARC-11 | CA-12 | Android↔Android | T2 | Archivo > 512 KiB | 1. Intentar enviarlo. | Bloqueado en el emisor con el límite explicado; si llegara oferta, el receptor la rechaza | pendiente | pendiente | `docs/img/android/45-ARC11-limite-tamano.png` |
| ARC-12 | CA-12 | Android↔Android | T1, T2 | Nombre `../x.txt` o extensión `.exe` (vía diagnóstico) | 1. Enviar oferta. | Receptor rechaza por nombre/tipo inválido; nada se escribe fuera de `recibidos/` | pendiente | pendiente | `docs/img/android/46-ARC12-nombre-invalido.png` |
| ARC-13 | CA-11 / R-08 | Android↔Android | T1 | Transferencia en curso | 1. Forzar detención de la app.<br>2. Reabrir y ver historial. | La transferencia aparece «fallida: interrumpida por reinicio», no completada | pendiente | pendiente | `docs/img/android/47-ARC13-reinicio.png` |
| ARC-14 | CA-12 | Android↔Android | T2 | Cola acotada | 1. Encolar 6 envíos. | Acepta 5 pendientes y avisa que la cola está llena | pendiente | pendiente | `docs/img/android/48-ARC14-cola-limite.png` |
| ARC-15 | CA-10 | Android↔Android | T1, T2 | Varias transferencias hechas | 1. Abrir Historial. | Estados pendiente/en curso/completado/cancelado/fallido correctos y persistentes | pendiente | pendiente | `docs/img/android/49-ARC15-historial.png` |

### Consulta web por Bluetooth (WEB)

A = teléfono con Internet (servidor, periférico). B = teléfono sin Wi-Fi ni datos (cliente, central). Recursos: ver `docs/protocolo.md` y lista blanca.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| WEB-01 | CA-13 | Android↔Android | A con Internet, B sin red | BLE conectado A↔B | 1. B: abrir `https://jsonplaceholder.typicode.com/todos/1`.<br>2. Observar B. | B muestra estado 200, JSON, tiempo en ms, insignia RED, rol cliente | pendiente | pendiente | `docs/img/android/50-WEB01-consulta-b-sin-red.png` |
| WEB-02 | CA-13 | Android↔Android | A sin Internet, B | A sin datos ni Wi-Fi | 1. B consulta una URL permitida. | B recibe `ERROR_WEB{red}` legible; A muestra el fallo | pendiente | pendiente | `docs/img/android/51-WEB02-a-sin-internet.png` |
| WEB-03 | CA-14 | Android↔Android | A, B | URL lenta (`https://httpbin.org/delay/15`) — fuera de lista: usar modo diagnóstico «Retraso» | 1. B consulta con retraso mayor a 10 s. | `ERROR_WEB{timeout}` en B; sin bloqueo de la UI | pendiente | pendiente | `docs/img/android/52-WEB03-timeout.png` |
| WEB-04 | CA-14 / R-11 | Android↔Android | A, B | Igual | 1. B pide `https://example.com/`. | Rechazada por dominio no permitido; A no abre conexión | pendiente | pendiente | `docs/img/android/53-WEB04-dominio-rechazado.png` |
| WEB-05 | CA-14 / R-11 | Android↔Android | A, B | Igual | 1. B pide `https://192.168.1.1/` y `https://localhost/`. | Rechazadas (IP literal / privada / loopback); sin tráfico | pendiente | pendiente | `docs/img/android/54-WEB05-ip-privada.png` |
| WEB-06 | CA-14 | Android↔Android | A, B | Redirección a destino no permitido (`https://httpbin.org/redirect-to?url=http://127.0.0.1`) | 1. B consulta. | A revalida cada salto y rechaza el destino; máx. 3 saltos | pendiente | pendiente | `docs/img/android/55-WEB06-redireccion.png` |
| WEB-07 | CA-15 | Android↔Android | A, B | Una consulta previa exitosa en B | 1. Apagar BT en A.<br>2. B repite la URL. | B informa pérdida de conexión y ofrece la copia de caché con fecha, insignia CACHÉ | pendiente | pendiente | `docs/img/android/56-WEB07-perdida-bt-cache.png` |
| WEB-08 | CA-15 / R-07 | Android↔Android | A, B | Diagnóstico «Duplicar petición» | 1. B envía la misma `req` dos veces. | A responde una vez a la red; la segunda recibe la respuesta guardada, sin segundo HTTPS | pendiente | pendiente | `docs/img/android/57-WEB08-peticion-duplicada.png` |
| WEB-09 | CA-14 | Android↔Android | A, B | Sesión nueva | 1. B hace 11 consultas en un minuto. | La 11.ª recibe `ERROR_WEB{limite}` | pendiente | pendiente | `docs/img/android/58-WEB09-limite-frecuencia.png` |
| WEB-10 | CA-13 | Android↔Android | A, B | Igual WEB-01 | 1. B pide `https://httpbin.org/image/jpeg`. | Imagen mostrada (≤ 64 KiB), tipo y bytes visibles | pendiente | pendiente | `docs/img/android/59-WEB10-imagen.png` |
| WEB-11 | CA-15 | Android↔Android | A, B | Varias consultas hechas | 1. Usar Atrás/Adelante.<br>2. Marcar favorito y reabrirlo. | Navegación del historial local correcta; favorito persiste | pendiente | pendiente | `docs/img/android/60-WEB11-atras-adelante-favoritos.png` |
| WEB-12 | CA-14 | Android↔Android | A, B | Igual | 1. B pide una URL de tipo no admitido o respuesta > 256 KiB (diagnóstico). | `ERROR_WEB{formato|tamano}` legible | pendiente | pendiente | `docs/img/android/61-WEB12-tipo-tamano.png` |

### Accesibilidad (ACC)

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| ACC-01 | R-12 | Android | Teléfono 1 | Texto del sistema al 200 % | 1. Recorrer sensores, biometría, transferencia, partida y consulta web. | Sin overflow ni texto cortado; todo operable | pendiente | pendiente | `docs/img/android/62-ACC01-texto-200.png` |
| ACC-02 | R-12 | Android | Teléfono 1 | TalkBack activo | 1. Navegar el panel de sensores y leer valor, unidad, estado e insignia. | Etiquetas coherentes; la insignia FÍSICA/SIMULADA se anuncia | pendiente | pendiente | `docs/img/android/63-ACC02-talkback-sensores.png` |
| ACC-03 | R-12 | Android | Teléfono 1 | TalkBack activo | 1. Aceptar una oferta y ver el progreso de transferencia. | Botones etiquetados; el progreso se anuncia; área táctil ≥ 48 dp | pendiente | pendiente | `docs/img/android/64-ACC03-talkback-transferencia.png` |
| ACC-04 | R-12 | Android | Teléfono 1 | Tema oscuro y azul | 1. Revisar contraste de insignias de estado. | Estados no dependen solo del color | pendiente | pendiente | `docs/img/android/65-ACC04-contraste.png` |

### Regresión Práctica 4 (REG)

Funciones previas deben seguir igual.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| REG-01 | CA-16 | Android | Teléfono 1, gestor | Datos de ejemplo | 1. Abrir TXT, JSON, XML e imagen. | Se ven sin error | pendiente | pendiente | `docs/img/android/66-REG01-archivos-p4.png` |
| REG-02 | CA-16 | Android | Teléfono 1, gestor | Carpeta SAF | 1. Crear, renombrar, copiar, mover (sin eliminar). | Operaciones correctas | pendiente | pendiente | `docs/img/android/67-REG02-saf-p4.png` |
| REG-03 | CA-16 | Android | Teléfono 1, juego | — | 1. Partida individual 4×4; guardar en TXT/XML/JSON y cargar. | Puntaje, tiempo y configuración conservados | pendiente | pendiente | `docs/img/android/68-REG03-guardado-p4.png` |
| REG-04 | CA-16 | Android | Teléfono 1 | — | 1. Cambiar tema Guinda/Azul y claro/oscuro. | Estado conservado | pendiente | pendiente | `docs/img/android/69-REG04-temas-p4.png` |
| REG-05 | CA-16 | Android | Teléfono 1, juego | Partida a medias | 1. Forzar detención y pulsar «Continuar». | Tablero recuperado | pendiente | pendiente | `docs/img/android/70-REG05-autoguardado-p4.png` |
| REG-06 | CA-16 | Android | Teléfono 1 | Modo avión | 1. Usar funciones locales de ambas apps. | Todo funciona sin Bluetooth ni red | pendiente | pendiente | `docs/img/android/71-REG06-offline-p4.png` |

### iOS — simulador Codemagic (IOS)

Sin iPhone físico: el simulador no tiene Bluetooth ni sensores. Solo se verifica que la app corre y degrada con mensajes.

| ID | Criterio / riesgo | Plataforma | Dispositivo / rol | Precondiciones | Pasos | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| IOS-01 | CA-17 | iOS simulador | Codemagic | Build exitoso | 1. Instalar y abrir el gestor.<br>2. Capturar pantalla inicial. | La app abre sin cierre | pendiente | pendiente | `docs/img/ios/72-IOS01-gestor-inicio.png` |
| IOS-02 | CA-17 | iOS simulador | Codemagic | Build exitoso | 1. Instalar y abrir el juego. | La app abre sin cierre | pendiente | pendiente | `docs/img/ios/73-IOS02-juego-inicio.png` |
| IOS-03 | CA-17 / R-13 | iOS simulador | Codemagic | — | 1. Abrir transferencia o partida por Bluetooth. | Mensaje «Bluetooth no disponible»; sin cierre | pendiente | pendiente | `docs/img/ios/74-IOS03-bt-no-disponible.png` |
| IOS-04 | CA-17 / R-13 | iOS simulador | Codemagic | — | 1. Abrir sensores. | Estado `ausente` con mensaje; sin cierre | pendiente | pendiente | `docs/img/ios/75-IOS04-sensores-ausentes.png` |
| IOS-05 | CA-17 | iOS simulador | Codemagic | — | 1. Eliminar en el gestor. | Mensaje claro de biometría no disponible/no enrolada, o autenticación simulada del simulador | pendiente | pendiente | `docs/img/ios/76-IOS05-biometria.png` |
| IOS-06 | CA-16 | iOS simulador | Codemagic | — | 1. Recorrido P4: abrir archivos y jugar 4×4. | Sin regresiones | pendiente | pendiente | `docs/img/ios/77-IOS06-regresion-p4.png` |
| IOS-07 | R-12 | iOS simulador | Codemagic | Texto ampliado | 1. Recorrer pantallas nuevas. | Sin overflow | pendiente | pendiente | `docs/img/ios/78-IOS07-texto-grande.png` |

Total planificado: 78 casos. Evidencia de sesiones y transferencias entre
dos teléfonos: además de capturas, el **video continuo con ambos dispositivos**
(`docs/video/`) exigido por el enunciado; el nombre del archivo se registra aquí
al grabarlo: `<por llenar>`.

## Matriz de transporte y pares

| Transporte | Par de SO | Roles (periférico ↔ central) | Casos | Estado |
|---|---|---|---|---|
| BLE (GATT propio) | Android ↔ Android | T1 periférico ↔ T2 central, y viceversa | JUE-*, ARC-*, WEB-* | Planificado — `pendiente` |
| BLE | Android ↔ iOS | — | — | **No verificado** (no hay iPhone) |
| BLE | iOS ↔ iOS | — | — | **No verificado** (no hay iPhone) |
| BLE | iOS simulador | — | IOS-03 | Sin Bluetooth en el simulador; solo mensaje de degradación |
| Bluetooth Clásico (RFCOMM) | cualquiera | — | — | **No implementado** (opcional en el enunciado; BLE cubre iOS) |

Pares realmente probados: `<por llenar>`. No se declara compatibilidad con
ningún par sin su evidencia.

## Pruebas automatizadas

Se ejecutan antes de la evidencia en dispositivo (`flutter analyze` y
`flutter test` por paquete).

| Paquete | Qué cubre | Pruebas | Resultado |
|---|---|---|---|
| `packages/comun` | Temas, resaltado, textos | `<por llenar>` | `<por llenar>` |
| `packages/sensores` | Controlador (ciclo de vida, ausente, sin datos), detectores de sacudida/inclinación/giro, fuente simulada | `<por llenar>` | `<por llenar>` |
| `packages/enlace_ble` | Fragmentación/reensamblado, sobre y versión, control de duplicados, ACK/reintentos, transferencia (bloques, SHA-256, cancelación, pérdida), validación web (lista blanca, IP privadas, redirecciones, límites) sobre `TransporteMemoria` | `<por llenar>` | `<por llenar>` |
| `apps/gestor_archivos` | Servicios de archivos, cola e historial, validación de nombre/tamaño, widgets | `<por llenar>` | `<por llenar>` |
| `apps/juego_pares` | Motor, sesión de red (turnos, duplicados), widgets | `<por llenar>` | `<por llenar>` |

Las pruebas automatizadas **no** sustituyen a los casos con hardware: BLE real,
MTU y sensores solo se verifican en teléfonos.

## Defectos

| ID | Caso | Pasos para reproducir | Esperado | Observado | Severidad (justificación) | Estado (corregido / preexistente / pendiente) | Evidencia |
|---|---|---|---|---|---|---|---|
| D-01 | `<por llenar>` | | | | | | |

Si no se hallan defectos se dirá qué se probó y qué limitaciones quedan; no se
inventan.

## Dictamen

- Casos ejecutados / aprobados / fallidos / bloqueados: `<por llenar>`
- SHA final y relación con el SHA probado: `<por llenar>`
- Riesgos que permanecen: pares Android↔iOS e iOS↔iOS sin verificar; RFCOMM no implementado; rendimiento BLE dependiente del teléfono.
- Recomendación: `<por llenar>`
