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

# Descargar el módulo de loopback virtual snd-aloop al volver a SOF interno
doas modprobe -r snd-aloop 2>/dev/null || true

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
# Configuración ALSA limpia para SOF Audio Interno
pcm.dmix_sof {
    type dmix
    ipc_key 1024
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:${CARD_NAME},0"
        rate 48000
    }
}

pcm.dsnoop_sof {
    type dsnoop
    ipc_key 1025
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:${CARD_NAME},0"
        rate 48000
        channels 1
    }
}

pcm.dsnoop_mic {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.!default {
    type asym
    playback.pcm "plug:dmix_sof"
    capture.pcm "plug:dsnoop_mic"
}

pcm.!sysdefault {
    type plug
    slave.pcm "default"
}

ctl.!default {
    type hw
    card "${CARD_NAME}"
}
EOC

# Eliminar ~/.asoundrc conflictivo del usuario para mantener la configuración centralizada en /etc/asound.conf
rm -f "$HOME/.asoundrc" 2>/dev/null || true

# Reiniciar el streaming de GStreamer del servicio loopback-tampermonkey si está activo
pkill -f "gst-launch-1.0.*plug:dsnoop_mic" 2>/dev/null || true
curl -s "http://127.0.0.1:8888/resume" >/dev/null 2>&1 || true

echo "[OK] Audio configurado a sof-snd-dsp (${CARD_NAME})"

