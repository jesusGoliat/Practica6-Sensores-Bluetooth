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

Completar durante la ejecución:

- `<por llenar>` Error de la IA detectado, cómo se detectó y cómo se corrigió.
- `<por llenar>`
- `<por llenar>`
