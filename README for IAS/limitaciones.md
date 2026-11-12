# Limitaciones

- **Sin iPhone.** iOS solo se ejecuta en el simulador de Codemagic, que no tiene Bluetooth ni sensores de movimiento. Los pares Android↔iOS e iOS↔iOS quedan **declarados no verificados**; el código usa APIs multiplataforma, pero no se afirma compatibilidad.
- **Segundo teléfono prestado.** Las pruebas de dos dispositivos dependen de la disponibilidad del teléfono prestado; solo se declaran los modelos y versiones realmente usados. Resultados con otros modelos pueden variar.
- **Sin emulador de Android.** Todo se prueba en teléfonos físicos por USB.
- **Rendimiento BLE.** El caudal y el MTU dependen del teléfono; por eso el límite de 512 KiB y el fragmento según MTU negociado.
- **Sin trabajo en segundo plano.** La sesión BLE puede perderse al minimizar; las suscripciones de sensores se detienen en segundo plano.
- **Sin reanudación de archivos.** Una transferencia interrumpida se reenvía completa.
- **SHA-256 no autentica** y el cifrado del enlace depende del emparejamiento del sistema; no hay criptografía propia.
- **Consulta web acotada** a una lista blanca de dominios de prueba; no es un navegador general.
- **RFCOMM no implementado.**
- **Biometría** depende de lo enrolado en el teléfono de prueba.
