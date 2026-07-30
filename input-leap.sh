#!/bin/sh

# --- Configuración de variables ---
TIEMPO_ESPERA=12
DELAY_TECLAS_MS=800  # 100 milisegundos = 0.1 segundos

# 1. Iniciar input-leap en segundo plano
input-leap &

# 2. Cuenta regresiva visual en pantalla
(
    i=$TIEMPO_ESPERA
    while [ "$i" -gt 0 ]; do
        echo "Lanzando macro en: $i"
        sleep 1
        i=$((i - 1))
    done
) | osd_cat -p middle -A center -l 1 -c green -d 1

# 3. Secuencia de pulsaciones y escritura
xdotool key Alt+c
sleep 0.5
xdotool key Alt+c
sleep 0.5
xdotool key Alt+c
sleep 0.5
xdotool key Alt+c