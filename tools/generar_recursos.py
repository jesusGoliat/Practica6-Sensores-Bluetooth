#!/usr/bin/env python3
"""Genera los recursos originales de la Práctica 4 (imágenes y sonidos).

No usa recursos de terceros: todo se dibuja o sintetiza aquí para que las
apps sean 100 % offline y sin problemas de licencias.
"""
from __future__ import annotations

import math
import os
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
DEMO = RAIZ / "apps" / "gestor_archivos" / "assets" / "demo"
AUDIO = RAIZ / "apps" / "juego_pares" / "assets" / "audio"
ICONOS = RAIZ / "tools" / "iconos"


def gradiente(ancho: int, alto: int, arriba: tuple[int, int, int], abajo: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (ancho, alto))
    px = img.load()
    for y in range(alto):
        t = y / max(1, alto - 1)
        color = tuple(int(arriba[i] * (1 - t) + abajo[i] * t) for i in range(3))
        for x in range(ancho):
            px[x, y] = color
    return img


def paisaje_escom() -> None:
    """Ilustración abstracta del campus: edificios, sol, árboles y circuito."""
    W, H = 1400, 900
    img = gradiente(W, H, (108, 29, 69), (0, 59, 92))
    d = ImageDraw.Draw(img, "RGBA")

    # Sol y halo
    d.ellipse((1000, 90, 1220, 310), fill=(255, 214, 120, 230))
    d.ellipse((940, 30, 1280, 370), outline=(255, 230, 160, 80), width=10)

    # Colinas
    d.polygon([(0, 640), (260, 470), (520, 630), (760, 430), (1030, 620), (1400, 460), (1400, 900), (0, 900)],
              fill=(24, 48, 58, 255))
    d.polygon([(0, 730), (300, 590), (620, 740), (920, 560), (1230, 730), (1400, 660), (1400, 900), (0, 900)],
              fill=(16, 31, 40, 255))

    # Edificios del campus
    edificios = [
        (150, 500, 420, 780, (236, 232, 220)),
        (450, 420, 700, 780, (248, 244, 232)),
        (730, 540, 980, 780, (226, 222, 210)),
        (1010, 470, 1240, 780, (240, 236, 224)),
    ]
    for x1, y1, x2, y2, color in edificios:
        d.rectangle((x1, y1, x2, y2), fill=color)
        d.rectangle((x1, y1, x2, y1 + 18), fill=(108, 29, 69))
        for vx in range(x1 + 28, x2 - 20, 58):
            for vy in range(y1 + 46, y2 - 20, 56):
                d.rectangle((vx, vy, vx + 28, vy + 30), fill=(60, 90, 110, 210))
        # Puerta
        cx = (x1 + x2) // 2
        d.rectangle((cx - 26, y2 - 68, cx + 26, y2), fill=(60, 35, 45))

    # Árboles
    for cx, cy, r in [(80, 720, 80), (330, 820, 95), (1280, 800, 85), (1380, 700, 70), (880, 820, 70)]:
        d.rectangle((cx - 8, cy, cx + 8, cy + 90), fill=(54, 37, 30))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(30, 104, 78, 240))

    # Circuito decorativo
    puntos = [(120, 200), (300, 200), (300, 330), (500, 330), (500, 160), (700, 160)]
    d.line(puntos, fill=(255, 255, 255, 110), width=8, joint="curve")
    for x, y in puntos:
        d.ellipse((x - 11, y - 11, x + 11, y + 11), fill=(255, 255, 255, 180))

    # Texto sin depender de fuentes externas
    d.rectangle((70, 70, 560, 130), fill=(0, 0, 0, 90))
    d.text((92, 88), "ESCOM  IPN  -  Campus", fill=(255, 255, 255, 230))

    DEMO.mkdir(parents=True, exist_ok=True)
    img.save(DEMO / "paisaje_escom.png", "PNG", optimize=True)


def icono(nombre: str, base: tuple[int, int, int]) -> None:
    """Icono cuadrado con una retícula de memoria (motivo del juego)."""
    S = 1024
    img = gradiente(S, S, base, tuple(max(0, c - 40) for c in base))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((120, 120, 904, 904), radius=120, outline=(255, 255, 255, 210), width=34)
    for i in range(3):
        for j in range(3):
            x = 210 + i * 220
            y = 210 + j * 220
            color = (255, 255, 255, 235) if (i + j) % 2 == 0 else (255, 255, 255, 120)
            d.rounded_rectangle((x, y, x + 150, y + 150), radius=28, fill=color)
    d.text((400, 940), "IPN", fill=(255, 255, 255, 220))
    ICONOS.mkdir(parents=True, exist_ok=True)
    img.save(ICONOS / f"{nombre}.png", "PNG", optimize=True)


def guardar_wav(ruta: Path, muestras: list[float], tasa: int = 44100) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ruta), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(tasa)
        datos = b"".join(struct.pack("<h", max(-32767, min(32767, int(m * 32767)))) for m in muestras)
        w.writeframes(datos)


def tono(freq: float, dur: float, volumen: float = 0.35, forma: str = "seno", tasa: int = 44100) -> list[float]:
    n = int(tasa * dur)
    out = []
    for i in range(n):
        t = i / tasa
        env = min(1.0, i / (tasa * 0.01), (n - i) / (tasa * 0.04))
        if forma == "cuadrada":
            v = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
        elif forma == "triangular":
            v = 2 * abs(2 * (t * freq - math.floor(t * freq + 0.5))) - 1
        else:
            v = math.sin(2 * math.pi * freq * t)
        out.append(v * volumen * env)
    return out


def silencio(dur: float, tasa: int = 44100) -> list[float]:
    return [0.0] * int(tasa * dur)


def audios() -> None:
    # Voltear: clic corto ascendente
    guardar_wav(AUDIO / "voltear.wav", tono(520, 0.05, 0.28) + tono(760, 0.05, 0.24))
    # Acierto: dos notas alegres
    guardar_wav(AUDIO / "acierto.wav", tono(660, 0.09, 0.32) + tono(880, 0.12, 0.32))
    # Error: zumbido grave
    guardar_wav(AUDIO / "error.wav", tono(180, 0.16, 0.30, "cuadrada") + tono(140, 0.12, 0.24, "cuadrada"))
    # Victoria: arpegio
    victoria: list[float] = []
    for f in (523.25, 659.25, 783.99, 1046.5):
        victoria += tono(f, 0.13, 0.30)
    victoria += tono(1318.5, 0.28, 0.28)
    guardar_wav(AUDIO / "victoria.wav", victoria)


if __name__ == "__main__":
    paisaje_escom()
    icono("guinda", (108, 29, 69))
    icono("azul", (0, 59, 92))
    audios()
    print("Recursos generados en", DEMO, AUDIO, ICONOS)
