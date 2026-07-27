#!/bin/bash
# Script: /home/user/monoliths-llm/JBL-Quantum350-wireless.sh
# Conmuta manualmente al dispositivo USB Wireless JBL Quantum350

# Cargar módulo snd-usb-audio por si acaso no estuviera cargado aún
doas modprobe snd-usb-audio 2>/dev/null || true
sleep 0.5

# Validar si el dispositivo USB Audio Wireless está conectado físicamente y detectado
CONNECTED=false
if lsusb 2>/dev/null | grep -i -E "0ecb:206b|JBL|Quantum350|Wireless" >/dev/null; then
    CONNECTED=true
elif grep -q -i "wireless" /proc/asound/cards 2>/dev/null; then
    CONNECTED=true
fi

if [ "$CONNECTED" = false ]; then
    # Mostrar alerta YAD
    yad --image=dialog-warning \
        --title="Audio USB Wireless" \
        --text="no ha conectado usb audio wireless" \
        --button=GTK_STOCK_OK:0 \
        --width=350 --center 2>/dev/null
    
    # Escapar ejecutando la configuración por defecto de audio interno
    /home/user/monoliths-llm/sof-snd-dsp.sh
    exit 1
fi

ASOUND_CONF="/etc/asound.conf"

doas tee "$ASOUND_CONF" >/dev/null <<EOC
pcm.!default {
    type plug
    slave.pcm {
        type dmix
        ipc_key 1024
        ipc_key_add_uid false
        ipc_perm 0666
        slave {
            pcm "hw:Wireless,0"
            rate 48000
        }
    }
}

pcm.!sysdefault {
    type plug
    slave.pcm {
        type dmix
        ipc_key 1024
        ipc_key_add_uid false
        ipc_perm 0666
        slave {
            pcm "hw:Wireless,0"
            rate 48000
        }
    }
}

ctl.!default {
    type hw
    card "Wireless"
}
EOC

# Reiniciar el servicio de audio de Google Chrome
pkill -9 -f "chrome.*audio.mojom.AudioService" 2>/dev/null || true
pkill -9 -f "chrome.*AudioService" 2>/dev/null || true

echo "[OK] Audio configurado a USB Wireless JBL Quantum350"
