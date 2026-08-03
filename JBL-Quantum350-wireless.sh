#!/bin/bash
# Script: /home/user/monoliths-llm/JBL-Quantum350-wireless.sh
# Conmuta manualmente al dispositivo USB Wireless JBL Quantum350

# Cargar módulos de audio USB con parámetros de ultra-baja latencia y Loopback Virtual
doas rmmod snd_usb_audio 2>/dev/null || true
doas modprobe snd-usb-audio lowlatency=1 implicit_fb=0 2>/dev/null || true
doas modprobe snd-aloop 2>/dev/null || true
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
# Configuración ALSA limpia y multiplexada para JBL Quantum 350
pcm.dsnoop_mic {
    type dsnoop
    ipc_key 1025
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:Wireless,0"
        rate 48000
        channels 1
        period_size 4
        period_time 0
        buffer_size 8
    }
}

pcm.dmix_speaker {
    type dmix
    ipc_key 1024
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:Wireless,0"
        rate 48000
        period_size 4
        period_time 0
        buffer_size 8
    }
}

pcm.!default {
    type asym
    playback.pcm "plug:dmix_speaker"
    capture.pcm "plug:dsnoop_mic"
}

pcm.!sysdefault {
    type plug
    slave.pcm "default"
}

ctl.!default {
    type hw
    card "Wireless"
}
EOC

# Reiniciar el streaming de GStreamer del servicio loopback-tampermonkey si está activo
pkill -f "gst-launch-1.0.*plug:dsnoop_mic" 2>/dev/null || true
curl -s "http://127.0.0.1:8888/resume" >/dev/null 2>&1 || true

echo "[OK] Audio configurado a USB Wireless JBL Quantum350 (dsnoop + dmix activos)"



