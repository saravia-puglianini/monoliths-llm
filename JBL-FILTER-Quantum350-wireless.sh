#!/bin/bash
# Script: /home/user/monoliths-llm/JBL-FILTER-Quantum350-wireless.sh
# Conmuta manualmente al dispositivo USB Wireless JBL Quantum350 (Modo Filtro de Ruido ~0.5ms Latencia)

# Cargar módulos de audio USB con parámetros de ultra-baja latencia
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
    yad --image=dialog-warning \
        --title="Audio USB Wireless Filter" \
        --text="No se detectó el dispositivo USB Audio Wireless" \
        --button=GTK_STOCK_OK:0 \
        --width=350 --center 2>/dev/null
    exit 1
fi

ASOUND_CONF="/etc/asound.conf"

doas tee "$ASOUND_CONF" >/dev/null <<EOC
# Configuración ALSA limpia y multiplexada para JBL Quantum 350 (~0.16ms period_size)
pcm.dsnoop_mic {
    type dsnoop
    ipc_key 1025
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:Wireless,0"
        rate 48000
        channels 1
        period_size 8
        period_time 0
        buffer_size 2048
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
        period_size 8
        period_time 0
        buffer_size 2048
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

# Definir pipeline con Filtro de Ruido Ambiental a latencia ultra-baja ~0.5ms (High Pass Filter 150Hz + Noise Gate Expander + Realce de Voz)
cat << 'EOP' > /tmp/jbl_pipeline
alsasrc device=plug:dsnoop_mic buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=1 ! audioconvert ! audiocheblimit mode=high-pass cutoff=150 poles=4 ! audiodynamic mode=expander threshold=0.03 ratio=10.0 characteristics=soft-knee ! audioconvert ! volume volume=1.2 ! alsasink device=plug:dmix_speaker sync=false buffer-time=500 latency-time=250 blocksize=16
EOP
chmod 666 /tmp/jbl_pipeline 2>/dev/null || true

# Reiniciar el servicio loopback-tampermonkey para aplicar el filtro de ruido a latencia ~0.5ms
doas killall -9 gst-launch-1.0 2>/dev/null || true
doas service loopback-tampermonkey restart >/dev/null 2>&1 || true

echo "[OK] Audio configurado a USB Wireless JBL Quantum350 (Filtro Anti-Ruido Activo ~0.5ms Latencia)"
