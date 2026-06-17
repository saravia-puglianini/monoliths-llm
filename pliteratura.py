#!/usr/bin/env python3
# FILE: $HOME/pliteratura/pliteratura.py

"""
TTS español con eSpeak + suavizado avanzado en Python
----------------------------------------------------

- Genera WAV usando eSpeak en español.
- Aplica suavizado gaussiano, filtro por convolución, efecto estéreo leve y eco.
- Permite parámetros personalizados: voz, archivo de salida y texto.
"""

import sys
import subprocess
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.ndimage import gaussian_filter1d
from scipy.signal import convolve

# --------------------------
# Parámetros desde la línea de comandos
# --------------------------
if len(sys.argv) < 4:
    print("Uso: python3 pvoz-suave.py VOZ TMP_WAV TEXTO_LIMPIO")
    sys.exit(1)

VOZ = sys.argv[1]
TMP_WAV = sys.argv[2]       # Archivo final
TEXTO_LIMPIO = sys.argv[3]

# --------------------------
# Generar WAV con eSpeak
# --------------------------
cmd = [
    "espeak",
    "-v", VOZ,        # Voz/idioma
    "-s", "135",      # velocidad
    "-p", "20",       # pitch
    "-a", "200",      # volumen
    "-g", "3",        # pausa entre palabras
    "-w", TMP_WAV,    # archivo WAV final
    TEXTO_LIMPIO
]

try:
    print("Generando audio con eSpeak...")
    subprocess.run(cmd, check=True)  # quité stderr DEVNULL para ver errores
except FileNotFoundError:
    print("Error: eSpeak no está instalado o no se encuentra en PATH.")
    sys.exit(1)

# --------------------------
# Leer WAV y aplicar efectos
# --------------------------
data, samplerate = sf.read(TMP_WAV)

# 1. Suavizado gaussiano
if data.ndim == 1:
    data = gaussian_filter1d(data, sigma=3)
else:
    data = np.stack([gaussian_filter1d(data[:,0], sigma=3),
                     gaussian_filter1d(data[:,1], sigma=3)], axis=1)

# 2. Suavizado simple con convolución (filtro promedio)
kernel_size = 9
kernel = np.ones(kernel_size) / kernel_size

if data.ndim == 1:
    data = convolve(data, kernel, mode='same')
else:
    data = np.stack([convolve(data[:,0], kernel, mode='same'),
                     convolve(data[:,1], kernel, mode='same')], axis=1)

# 3. Efecto estéreo leve (solo si es mono)
if data.ndim == 1:
    delay = int(0.02 * samplerate)  # 10 ms
    stereo = np.zeros((len(data), 2))
    stereo[:,0] = data
    stereo[delay:,1] = data[:-delay]
    data = stereo

# 4. Eco / reverberación leve
decay = 2
if data.ndim == 1:
    echo = np.zeros_like(data)
    echo[1:] = data[:-1] * decay
    data = data + echo
else:
    for ch in range(2):
        echo = np.zeros_like(data[:,ch])
        echo[1:] = data[:-1,ch] * decay
        data[:,ch] += echo

# Normalizar para evitar saturación
max_val = np.max(np.abs(data))
if max_val > 1.0:
    data = data / max_val

# Sobrescribir el archivo final
sf.write(TMP_WAV, data, samplerate)
print(f"Audio final generado y suavizado con efectos: {TMP_WAV}")

# HOW TO BUILD
# Run
# 1. `mkdir -p $HOME/pliteratura`
# 2. `cp $HOME/monoliths-llm/pliteratura.py $HOME/pliteratura/pliteratura.py`
# 2. `cd $HOME/pliteratura`
# 3. `virtualenv -p python3 venv`
# 4. `source venv/bin/activate`
# 5. `doas pacman -S espeak openblas cmake gcc-fortran meson`
# 6. `pip install numpy soundfile`
# 7. `pip install scipy --prefer-binary`
# 8. `python3 pliteratura.py 'es' '/tmp/tmpfile.wav' 'Esto es una prueba de voz limpia, leyendo el archivo temporal enviado'`
# 9. `mpv /tmp/tmpfile.wav`
# # Binary
# pip install pyinstaller
# pyinstaller --onefile pliteratura.py
# Ahora tendrás $HOME/pliteratura/dist/pliteratura listo para ejecutar
# ONE STROKE
# type bash in prompt and do the next stroke
# mkdir -p $HOME/pliteratura && cp $HOME/monoliths-llm/pliteratura.py $HOME/pliteratura/pliteratura.py && cd $HOME/pliteratura && virtualenv -p python3 venv && source venv/bin/activate && doas pacman -S espeak openblas cmake gcc-fortran meson && pip install numpy soundfile && pip install scipy --prefer-binary && python3 pliteratura.py 'es' '/tmp/tmpfile.wav' 'Esto es una prueba de voz limpia, leyendo el archivo temporal enviado' && mpv /tmp/tmpfile.wav
