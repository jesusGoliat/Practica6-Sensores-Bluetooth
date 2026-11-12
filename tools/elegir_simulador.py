#!/usr/bin/env python3
"""Elige un simulador iPhone disponible en el runner macOS e imprime su UDID.

No fija nombres como "iPhone 15": los runners de GitHub cambian de runtime.
"""
from __future__ import annotations

import json
import subprocess
import sys


def main() -> int:
    salida = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
    )
    datos = json.loads(salida)
    candidatos: list[tuple[str, str, str]] = []
    for runtime, dispositivos in datos.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for dispositivo in dispositivos:
            nombre = dispositivo.get("name", "")
            if dispositivo.get("isAvailable") and nombre.startswith("iPhone"):
                candidatos.append((runtime, nombre, dispositivo["udid"]))
    if not candidatos:
        print("No hay simuladores iPhone disponibles", file=sys.stderr)
        return 1
    # Preferir el runtime más reciente; dentro de él, el primer iPhone.
    candidatos.sort(key=lambda c: (c[0], c[1]), reverse=True)
    print(candidatos[0][2])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
