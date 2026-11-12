# Uso de IA

## Declaración

Se usó **Claude Code** (modelo Opus como orquestador y subagentes Sonnet) para
generar código, documentación y pruebas de esta práctica. El autor definió el
alcance, el diseño (`docs/diseno-p6.md`) y revisó el resultado.

## Cómo se verificó

| Medio | Detalle |
|---|---|
| Análisis estático | `flutter analyze` por paquete y app |
| Pruebas automatizadas | `flutter test` (lógica, mensajes y protocolo sobre transporte en memoria) |
| Dispositivos físicos | Ejecución en teléfonos Android por USB; resultados en `docs/pruebas.md` |
| Revisión manual | Lectura del código y de los documentos generados; contraste con el enunciado |
| Simulador iOS | Solo comprueba que la app abre y degrada (Codemagic) |

Las afirmaciones de funcionamiento con hardware solo valen si hay evidencia
registrada; lo demás permanece `pendiente`.

## Errores detectados

- **Dependencia incompatible con la toolchain.** La IA eligió `permission_handler` 13.x, que exige `compileSdk` 37, y AGP 9.1 recomienda como máximo 36. La compilación de humo falló y se fijó la versión 12.0.x.
- **Anuncio BLE inviable en Android.** El servidor BLE generado anunciaba un nombre local, pero en Android el plugin lo implementa con `BluetoothAdapter.setName()` (renombra el teléfono) y además no cabe junto al UUID de 128 bits. Se cambió a datos de fabricante en el anuncio (PR #12).
- **Resultado reportado sin verificar.** Un subagente informó 35/35 pruebas del juego en verde, pero la prueba de red fallaba al ejecutarse en paralelo (esperas de 3 ms). Se detectó al volver a ejecutar las pruebas y se corrigió.
- **Documentación desalineada con el código.** Los códigos de error web del paquete no coincidían con `docs/protocolo.md` §9; se actualizó el documento contra el código.
