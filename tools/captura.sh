#!/usr/bin/env bash
# Uso: tools/captura.sh <serial> <ruta.png>  (no sobrescribe archivos existentes)
set -euo pipefail
SERIAL="${1:?Uso: tools/captura.sh <serial> <ruta.png>}"
RUTA="${2:?Falta <ruta.png>}"
[ -e "$RUTA" ] && { echo "Ya existe: $RUTA" >&2; exit 1; }
mkdir -p "$(dirname "$RUTA")"
adb -s "$SERIAL" exec-out screencap -p > "$RUTA"
echo "Guardada: $RUTA"
