#!/bin/bash
# Script: /home/user/monoliths-llm/inhibir-ambiente.sh
# Genera y reproduce un sonido de interferencia/ruido rosa sintetizado con ffmpeg en bucle continuo
# para inhibir/enmascarar el ruido ambiental no deseado.

PID_FILE="/tmp/inhibir_ambiente.pid"

# Si ya hay un ffmpeg ejecutando anoisesrc, lo matamos (desactivar)
if pgrep -f "anoisesrc=c=pink" >/dev/null 2>&1; then
    pkill -f "anoisesrc=c=pink" 2>/dev/null
    rm -f "$PID_FILE"
    echo "Inhibidor de ambiente desactivado."
    exit 0
fi

# Si no está ejecutándose, lo iniciamos en segundo plano (activar)
ffmpeg -loglevel quiet -re -f lavfi -i "anoisesrc=c=pink:r=48000:a=0.20" -f alsa default >/dev/null
echo $! > "$PID_FILE"
echo "Inhibidor de ambiente activado."
