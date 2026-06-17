#!/usr/bin/env python3
# FILE: $HOME/coqui-tts/pcoqui-tts.py

"""
Mini sintetizador de voz en español usando Coqui TTS
---------------------------------------------------

Este script lee un texto desde un archivo o desde la línea de comandos
y genera un archivo de audio con voz sintetizada en español.

Requisitos:
- Python 3.8+
- coqui-ai-tts
- Modelo de voz en español disponible en TTS

"""

import sys
from pathlib import Path
from TTS.api import TTS

# --------------------------
# CONFIGURACIÓN
# --------------------------
DOCUMENT_PATH = "documento.txt"  # Archivo de texto
OUTPUT_AUDIO = "output.wav"      # Archivo de salida de audio
MODEL_NAME = "tts_models/es/tacotron2-DDC"  # Modelo TTS español (Coqui)

# --------------------------
# Cargar texto
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
# Inicializar TTS
# --------------------------
tts = TTS(MODEL_NAME)

# --------------------------
# Generar audio
# --------------------------
print("Generando audio...")
tts.tts_to_file(text=text, file_path=OUTPUT_AUDIO)
print(f"Audio generado: {OUTPUT_AUDIO}")

# HOW TO BUILD
# Run
# 1. `mkdir -p $HOME/coqui-tts`
# 2. `cd $HOME/coqui-tts`
# 3. `virtualenv -p python3 venv`
# 4. `source venv/bin/activate`
# 5. `echo "TTS" > requirements.txt`
# 6. `pip install -r requirements.txt`
# 7. `python3 pcoqui-tts.py 'Hola, esto es una prueba de voz en español'`
# # Binary
# pip install pyinstaller
# pyinstaller --onefile pcoqui-tts.py
# Ahora tendrás $HOME/coqui-tts/dist/pcoqui-tts listo para ejecutar
