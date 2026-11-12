#!/usr/bin/env python3
"""Toca un nodo de la UI de Android por texto o content-desc.

Uso:
  tools/adb_ui.py "Azul ESCOM"     # toca el nodo
  tools/adb_ui.py --dump           # imprime los nodos con texto/desc
  tools/adb_ui.py --list           # solo lista
"""
from __future__ import annotations

import subprocess
import sys
import xml.etree.ElementTree as ET


def nodos() -> list[dict[str, str]]:
    subprocess.run(
        ["adb", "shell", "uiautomator", "dump", "/sdcard/ui.xml"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    xml = subprocess.check_output(["adb", "exec-out", "cat", "/sdcard/ui.xml"])
    raiz = ET.fromstring(xml)
    resultado = []
    for nodo in raiz.iter("node"):
        texto = nodo.get("text", "")
        desc = nodo.get("content-desc", "")
        if texto or desc:
            resultado.append({
                "texto": texto,
                "desc": desc,
                "bounds": nodo.get("bounds", ""),
                "clickable": nodo.get("clickable", "false"),
            })
    return resultado


def centro(bounds: str) -> tuple[int, int]:
    # [x1,y1][x2,y2]
    limpio = bounds.replace("][", ",").strip("[]").split(",")
    x1, y1, x2, y2 = map(int, limpio)
    return (x1 + x2) // 2, (y1 + y2) // 2


def main() -> int:
    objetivo = sys.argv[1] if len(sys.argv) > 1 else "--list"
    lista = nodos()
    if objetivo in {"--dump", "--list"}:
        for n in lista:
            print(f"texto={n['texto']!r} desc={n['desc']!r} bounds={n['bounds']} clickable={n['clickable']}")
        return 0

    candidatos = [n for n in lista if objetivo == n["texto"] or objetivo == n["desc"]]
    if not candidatos:
        candidatos = [n for n in lista if objetivo.lower() in (n["texto"] + " " + n["desc"]).lower()]
    if not candidatos:
        print(f"No se encontró: {objetivo}", file=sys.stderr)
        return 1
    n = candidatos[0]
    x, y = centro(n["bounds"])
    subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
    print(f"Tocado {objetivo!r} en ({x},{y})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
