# Decisiones (estilo ADR)

| # | Decisión | Contexto | Razón / consecuencia |
|---|---|---|---|
| 1 | Flutter, no KMP | El proyecto base de la Práctica 4 ya es Flutter | Reutiliza `comun` y las dos apps; un solo código para Android e iOS |
| 2 | `bluetooth_low_energy` | Se necesitan los dos roles (central y periférico) en Android e iOS | `flutter_blue_plus` es solo central, no puede anunciar ni servir |
| 3 | BLE y no RFCOMM | RFCOMM clásico no existe en iOS | BLE permite en teoría interoperar con iOS; RFCOMM se declara no implementado (opcional) |
| 4 | Sin reanudación de transferencias | Simplicidad y evitar archivos parciales | Tras perder el enlace queda `fallido`; reenviar empieza en el bloque 0 |
| 5 | Límite de archivo 512 KiB | BLE es lento y la práctica es didáctica | Transferencia de decenas de segundos como máximo |
| 6 | Lista blanca para la consulta web | A hace de proxy HTTPS para B | Reduce SSRF y abuso; solo cuatro dominios, HTTPS 443 |
| 7 | `local_auth` con credencial del dispositivo como alternativa | No todos los teléfonos tienen biometría | `biometricOnly: false`; sin ningún bloqueo la acción se bloquea con explicación |
| 8 | Codemagic para iOS | No hay Mac ni iPhone | Solo simulador, sin Bluetooth ni sensores (ver limitaciones) |
| 9 | Sensores tras interfaz con fuente simulada | Probar extremos y ausencia sin hardware | La UI distingue FÍSICA de SIMULADA |
| 10 | Notificaciones locales, no FCM | El enunciado excluye Firebase | Avisos solo con la app en primer plano o recién minimizada |
