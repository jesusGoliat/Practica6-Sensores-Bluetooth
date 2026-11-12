#!/usr/bin/env bash
# Toma capturas del celular Android conectado con adb exec-out screencap -p.
# Uso: tools/evidencia_android.sh <serial> <app> <prefijo> [nombre ...]
#   app: gestor | juego (subcarpeta de docs/img/android/)
#   Sin nombres, toma una captura <prefijo>.png; con nombres, una por cada uno
#   (<prefijo>_<nombre>.png), esperando Enter entre capturas.
set -euo pipefail
SERIAL="${1:?Uso: tools/evidencia_android.sh <serial> <app> <prefijo> [nombre ...]}"
APP="${2:?Falta <app>}"
PREFIJO="${3:?Falta <prefijo>}"
shift 3
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="$RAIZ/docs/img/android/$APP"
mkdir -p "$DESTINO"

tomar() {
  local archivo="$DESTINO/$1.png"
  if [ -e "$archivo" ]; then
    echo "Ya existe, no se sobrescribe: $archivo" >&2
    return 1
  fi
  adb -s "$SERIAL" exec-out screencap -p > "$archivo"
  echo "Guardada: $archivo"
}

if [ "$#" -eq 0 ]; then
  tomar "$PREFIJO"
else
  for nombre in "$@"; do
    read -r -p "Prepara la pantalla '$nombre' y presiona Enter... "
    tomar "${PREFIJO}_${nombre}"
  done
fi
