# consulta_web

Consulta web por Bluetooth de la Práctica 6. Contrato: `docs/diseno-p6.md`
(«Reglas de la consulta web») y `docs/protocolo.md` (canal `web`).

## Roles

* **A (servidor)**: tiene Internet. Anuncia `P6-web-xxxx` (`ServidorBle(app: 'web')`), recibe
  `PETICION`, valida, hace la petición HTTPS con `dart:io` y responde `RESPUESTA` o `ERROR_WEB`.
* **B (cliente)**: sin Wi‑Fi ni datos, solo Bluetooth. Busca servidores A, se conecta y envía
  `PETICION{req, url}`. **Nunca hace HTTP.**

## Recursos de prueba (lista blanca)

| URL | Contenido |
|---|---|
| `https://jsonplaceholder.typicode.com/todos/1` | JSON |
| `https://jsonplaceholder.typicode.com/posts/1` | JSON |
| `https://jsonplaceholder.typicode.com/users/1` | JSON |
| `https://httpbin.org/json` | JSON |
| `https://httpbin.org/uuid` | JSON |
| `https://httpbin.org/image/jpeg` | Imagen JPEG (~35 KB) |
| `https://api.github.com/zen` | Texto |
| `https://www.ipn.mx/robots.txt` | Texto |

Dominios: `jsonplaceholder.typicode.com`, `httpbin.org`, `api.github.com`, `www.ipn.mx`.

## Reglas de validación (en A, en cada salto)

1. Esquema `https`.
2. Sin usuario ni contraseña en la URL.
3. Host que no sea una IP literal.
4. Host en la lista blanca.
5. Puerto 443 (o vacío).
6. Resolución DNS: se rechaza si alguna dirección es loopback, privada (10/8, 172.16/12,
   192.168/16), link‑local (169.254/16, fe80::/10), CGNAT (100.64/10), ULA (fc00::/7), `::1`,
   `0.0.0.0/8` o `::ffff:` equivalentes.
7. Redirecciones: `followRedirects=false`; se siguen a mano, máximo 3, revalidando cada `Location`.

## Límites y formatos

* Timeout 10 s en total (incluye DNS, redirecciones y el retraso diagnóstico), 10 peticiones por
  minuto por sesión, cuerpo máximo 256 KiB.
* **Límite efectivo**: el enlace reensambla como máximo 64 KiB por mensaje, así que una respuesta
  cuyo sobre JSON supere ~64 000 B se devuelve como `demasiado_grande`. Una imagen de 64 KiB en
  base64 no cabría; las de ~35 KB de `httpbin.org/image/jpeg` sí.
* Admitidos: `text/plain`, `application/json`, `text/html` (se envía y muestra como texto, nunca
  se ejecuta), `image/jpeg|png` ≤ 64 KiB. Otro tipo: `formato_no_admitido`.

## Caché (en B)

* `url → {texto o bytes, tipo, estado, fecha}`; solo respuestas 2xx recibidas por la red.
* Máximo 30 entradas, expulsión LRU; se persiste como JSON (`consulta_web_cache.json`).
* Si no hay Bluetooth, A no responde en 20 s o el enlace se pierde: si la URL está en caché se
  muestra con la insignia **CACHÉ · dd/MM HH:mm** (ámbar, y con texto); si no, error. Una
  respuesta de la red lleva la insignia **RED** (verde). Los errores de A (`ERROR_WEB`) no usan caché.
* Una `req` ya contestada devuelve la respuesta guardada sin volver a salir a Internet (A).
  B ignora respuestas para `req` desconocidas, tardías o duplicadas.

## Códigos de error (`ERROR_WEB.codigo`)

| Código | Significado |
|---|---|
| `destino_rechazado` | Falló alguna regla de validación (campo extra `motivo`: `esquema`, `dominio`, `credenciales`, `ipLiteral`, `puerto`, `destinoPrivado`, `demasiadasRedirecciones`, `urlInvalida`) |
| `limite` | Más de 10 peticiones por minuto |
| `timeout` | Más de 10 s |
| `sin_internet` | A no tiene Internet (`SocketException`, incluido DNS) |
| `demasiado_grande` | Más de 256 KiB, o no cabe en un mensaje del enlace |
| `formato_no_admitido` | Tipo de contenido no admitido |
| `formato` | Petición mal formada |
| `red` | Otro fallo de red/TLS en A |

(Difieren de los nombres provisionales de la tabla 9 de `docs/protocolo.md`: `dominio`/`destino` →
`destino_rechazado`, `red` → `sin_internet`, `tamano` → `demasiado_grande`.)

## Cómo demostrarlo (B en modo avión)

1. A: Wi‑Fi o datos activos, Bluetooth encendido. Abrir *Consulta web* → **Servidor (A)**.
2. B: activar **modo avión** y luego solo **Bluetooth**; sin Wi‑Fi ni datos. Abrir la pantalla →
   **Cliente (B)** → *Buscar servidores* → elegir `P6-web-…`.
3. B: elegir un recurso del menú de la barra de dirección y pulsar **Ir**: aparece RED, estado,
   ms y el contenido (WEB‑01, WEB‑10).
4. Apagar Bluetooth en A y repetir la URL: B muestra CACHÉ con fecha (WEB‑07). Otra URL: error.
5. Timeout (WEB‑03): en A activar el interruptor **Retraso (diagnóstico)**; B recibe `timeout`.
6. Rechazos (WEB‑04/05/06): pedir `https://example.com/`, `https://192.168.1.1/`,
   `https://localhost/`.

## Uso desde la app

```dart
PantallaConsultaWeb(); // destino de navegación, usa BLE real y path_provider
```

Parámetros opcionales: `estado`, `puente` (`PuenteBle`), `almacen` (`AlmacenTexto`),
`mostrarAppBar`. La app debe declarar los permisos Bluetooth indicados en `enlace_ble`.
