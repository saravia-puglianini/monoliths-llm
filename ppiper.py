#!/usr/bin/env python3
# FILE: ppiper.py

"""
Mini TTS local usando Piper
----------------------------

Este script toma un texto desde la línea de comandos o un archivo documento.txt
y genera un archivo de audio WAV usando Piper en español.

Requisitos:
- Python 3.8+
- Piper (piper tts)
- Modelo de voz en español de Piper

"""

import sys
from pathlib import Path
import subprocess

DOCUMENT_PATH = "documento.txt"
OUTPUT_AUDIO = "output.wav"
PIPER_MODEL_PATH = "piper-es.pbmm"   # Modelo de voz en español
PIPER_CONFIG_PATH = "piper-config.json"  # Archivo de configuración del modelo

# --------------------------
# Leer texto
# --------------------------
if len(sys.argv) > 1:
    text = " ".join(sys.argv[1:])
elif Path(DOCUMENT_PATH).exists():
    with open(DOCUMENT_PATH, "r", encoding="utf-8") as f:
        text = f.read()
else:
    print("No se proporcionó texto ni se encontró documento.txt")
    sys.exit(1)

# --------------------------
# Generar audio usando Piper
# --------------------------
# Piper se ejecuta mediante subprocess llamando al ejecutable TTS
# https://github.com/rhasspy/piper

cmd = [
    "piper",               # ejecutable de Piper
    "--model", PIPER_MODEL_PATH,
    "--config", PIPER_CONFIG_PATH,
    "--text", text,
    "--out", OUTPUT_AUDIO
]

try:
    print("Generando audio con Piper...")
    subprocess.run(cmd, check=True)
    print(f"Audio generado: {OUTPUT_AUDIO}")
except FileNotFoundError:
    print("No se encontró el ejecutable de Piper. Instálalo siguiendo la documentación de Piper.")
except subprocess.CalledProcessError as e:
    print("Error al generar audio:", e)
