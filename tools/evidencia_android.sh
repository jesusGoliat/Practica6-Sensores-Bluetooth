#!/usr/bin/env bash
# Ejecuta los recorridos de integración en el celular Android conectado y
# copia las capturas a docs/img/android/. Uso: tools/evidencia_android.sh <serial>
set -euo pipefail
SERIAL="${1:?Uso: tools/evidencia_android.sh <serial>}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

echo "Dispositivo: $SERIAL"
adb -s "$SERIAL" shell getprop ro.product.model
adb -s "$SERIAL" shell getprop ro.build.version.release
adb -s "$SERIAL" shell getprop ro.build.version.sdk

cd "$RAIZ/apps/gestor_archivos"
rm -rf screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/evidencia_ios_test.dart -d "$SERIAL"
mkdir -p "$RAIZ/docs/img/android/gestor"
cp screenshots/*.png "$RAIZ/docs/img/android/gestor/"

cd "$RAIZ/apps/juego_pares"
rm -rf screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/evidencia_ios_test.dart -d "$SERIAL"
mkdir -p "$RAIZ/docs/img/android/juego"
cp screenshots/*.png "$RAIZ/docs/img/android/juego/"

echo "Capturas copiadas a docs/img/android/"
