# Arquitectura (resumen)

Monorepo Flutter:

- `apps/gestor_archivos` y `apps/juego_pares`: las dos apps.
- `packages/comun`: temas, textos y widgets compartidos.
- `packages/sensores`: sensores tras la interfaz `FuenteSensor` (física y simulada), controlador y detectores.
- `packages/enlace_ble`: protocolo en Dart puro (fragmentación, sobre, duplicados, transferencia, validador web) y transporte BLE.

Capas: datos (adaptadores de plataforma) / dominio (Dart puro, probado sin
dispositivo) / presentación (Flutter + Provider).

Detalle, diagramas y permisos: [`docs/arquitectura.md`](../docs/arquitectura.md).
Protocolo y secuencias: [`docs/protocolo.md`](../docs/protocolo.md).
Contrato de nombres y tipos: [`docs/diseno-p6.md`](../docs/diseno-p6.md).
