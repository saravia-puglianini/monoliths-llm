#!/bin/bash
# Script: /home/user/monoliths-llm/sof-snd-dsp.sh
# Habilita el audio interno SOF (sof-hda-dsp) de forma manual

ASOUND_CONF="/etc/asound.conf"

# Forzar dsp_driver=3 en modprobe para el driver SOF
if [ -f /etc/modprobe.d/alsa-legacy.conf ]; then
    echo "options snd-intel-dspcfg dsp_driver=3" | doas tee /etc/modprobe.d/alsa-legacy.conf >/dev/null
fi

# Eliminar cualquier blacklist previo que deshabilite SOF
if [ -f /etc/modprobe.d/blacklist-sof.conf ]; then
    doas rm -f /etc/modprobe.d/blacklist-sof.conf
fi

# Detectar el nombre exacto de la tarjeta interna en /proc/asound/cards
CARD_NAME="sof-hda-dsp"
if grep -q -i "sofhdadsp" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sofhdadsp"
elif grep -q -i "sof" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sof-hda-dsp"
elif grep -q -i "pch" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="PCH"
fi

doas tee "$ASOUND_CONF" >/dev/null <<EOC
pcm.!default {
    type plug
    slave.pcm {
        type dmix
        ipc_key 1024
        ipc_key_add_uid false
        ipc_perm 0666
        slave {
            pcm "hw:${CARD_NAME},0"
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
            pcm "hw:${CARD_NAME},0"
            rate 48000
        }
    }
}

ctl.!default {
    type hw
    card "${CARD_NAME}"
}
EOC

# Reiniciar el servicio de audio de Google Chrome
pkill -9 -f "chrome.*audio.mojom.AudioService" 2>/dev/null || true
pkill -9 -f "chrome.*AudioService" 2>/dev/null || true

echo "[OK] Audio configurado a sof-snd-dsp (${CARD_NAME})"
