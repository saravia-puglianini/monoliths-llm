#!/bin/bash
# Loop infinito que asegura el volumen del micrófono de JBL al 100% cada 0.5 segundos
export HOME="/home/user"
while true; do
    amixer -c Wireless sset Mic 100% unmute >/dev/null 2>&1
    sleep 0.5
done
