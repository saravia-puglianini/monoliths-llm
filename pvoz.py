#!/usr/bin/env python3
# FILE: pvoz-suave.py

"""
TTS español con eSpeak + suavizado en Python
--------------------------------------------

- Genera WAV usando eSpeak en español.
- Suaviza la voz y aplica un filtro ligero para que suene menos robótica.
- Funciona offline, sin sox ni librerías pesadas.
"""

import sys
import subprocess
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.signal import convolve

DOCUMENT_PATH = "documento.txt"
OUTPUT_WAV_RAW = "temp.wav"
OUTPUT_WAV_FINAL = "voz_suave.wav"

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
# Generar WAV con eSpeak
# --------------------------
# Parámetros optimizados: español latino, velocidad 130, pitch 50, volumen 200
cmd = [
    "espeak",
    "-v", "es",
    "-s", "130",
    "-p", "50",
    "-a", "200",
    "--stdout"
]

try:
    print("Generando audio con eSpeak...")
    with open(OUTPUT_WAV_RAW, "wb") as f:
        subprocess.run(cmd + [text], check=True, stdout=f)
except FileNotFoundError:
    print("Error: eSpeak no está instalado o no se encuentra en PATH.")
    sys.exit(1)

# --------------------------
# Leer WAV y aplicar suavizado
# --------------------------
data, samplerate = sf.read(OUTPUT_WAV_RAW)

# Suavizado simple con convolución (filtro promedio)
kernel_size = 5
kernel = np.ones(kernel_size) / kernel_size

if data.ndim == 1:
    smoothed = convolve(data, kernel, mode='same')
else:
    # si es estéreo
    smoothed = np.stack([convolve(data[:,0], kernel, mode='same'),
                         convolve(data[:,1], kernel, mode='same')], axis=1)

# Guardar WAV final
sf.write(OUTPUT_WAV_FINAL, smoothed, samplerate)
print(f"Audio final generado: {OUTPUT_WAV_FINAL}")

# HOW TO BUILD
# Run
# 1. `mkdir -p $HOME/voz`
# 2. `cd $HOME/voz`
# 3. `virtualenv -p python3 venv`
# 4. `source venv/bin/activate`
# 5. `pacman -S espeak openblas cmake gcc-fortran meson`
# 6. `pip install numpy soundfile`
# 7. `pip install scipy --prefer-binary`
# 8. `python3 pvoz.py 'Hola, esto es una prueba de voz en español'`
# # Binary
# pip install pyinstaller
# pyinstaller --onefile pvoz.py
# Ahora tendrás $HOME/voz/dist/voz listo para ejecutar
