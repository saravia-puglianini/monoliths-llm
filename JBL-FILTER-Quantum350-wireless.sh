#!/bin/bash
# Script: /home/user/monoliths-llm/JBL-FILTER-Quantum350-wireless.sh
# Conmuta manualmente al dispositivo USB Wireless JBL Quantum350 (Modo Filtro de Ruido ~0.5ms Latencia)

LOG_FILE="/tmp/jbl_filter.log"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

# Inicializar o limpiar el log anterior
echo "=== Inicio de Ejecución JBL-FILTER ($(date '+%Y-%m-%d %H:%M:%S')) ===" > "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

log "INFO" "Paso 1: Limpiando .asoundrc anterior si existe..."
if [ -f /home/user/.asoundrc ]; then
    if doas rm /home/user/.asoundrc 2>>"$LOG_FILE"; then
        log "OK" ".asoundrc eliminado correctamente."
    else
        log "WARNING" "No se pudo eliminar /home/user/.asoundrc."
    fi
else
    log "INFO" "No se encontró .asoundrc previo."
fi

log "INFO" "Paso 2: Recargando módulos de audio USB con parámetros de baja latencia..."
doas rmmod snd_usb_audio 2>>"$LOG_FILE" || true

if doas modprobe snd-usb-audio lowlatency=1 implicit_fb=0 2>>"$LOG_FILE"; then
    log "OK" "Módulo snd-usb-audio cargado exitosamente."
else
    log "ERROR" "Fallo al cargar el módulo snd-usb-audio."
fi

log "INFO" "Paso 3: Cargando módulo de Loopback Virtual (snd-aloop)..."
if doas modprobe snd-aloop 2>>"$LOG_FILE"; then
    log "OK" "Módulo snd-aloop cargado exitosamente."
else
    log "WARNING" "Fallo al cargar el módulo snd-aloop (puede que ya estuviera cargado)."
fi

sleep 0.5

log "INFO" "Paso 4: Validando conexión del dispositivo JBL Quantum 350..."
CONNECTED=false
if lsusb 2>/dev/null | grep -i -E "0ecb:206b|JBL|Quantum350|Wireless" >/dev/null; then
    CONNECTED=true
elif grep -q -i "wireless" /proc/asound/cards 2>/dev/null; then
    CONNECTED=true
fi

if [ "$CONNECTED" = false ]; then
    log "ERROR" "No se detectó el dispositivo USB Audio Wireless."
    yad --image=dialog-warning \
        --title="Audio USB Wireless Filter" \
        --text="No se detectó el dispositivo USB Audio Wireless" \
        --button=GTK_STOCK_OK:0 \
        --width=350 --center 2>/dev/null
    exit 1
else
    log "OK" "Dispositivo JBL Wireless detectado."
fi

ASOUND_CONF="/etc/asound.conf"
log "INFO" "Paso 5: Configurando $ASOUND_CONF..."

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

pcm.entrada_buena_jbl {
    type plug
    slave {
        pcm "dsnoop_mic"
    }
}

pcm.entrada_buena_16k_jbl {
    type plug
    slave {
        pcm "entrada_buena_jbl"
        rate 16000
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

if [ $? -eq 0 ]; then
    log "OK" "Configuración ALSA guardada exitosamente en $ASOUND_CONF."
else
    log "ERROR" "Fallo al escribir la configuración en $ASOUND_CONF."
fi

log "INFO" "Paso 6: Generando pipeline con Filtro de Ruido en /tmp/jbl_pipeline..."
cat << 'EOP' > /tmp/jbl_pipeline
alsasrc device=plug:dsnoop_mic buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=1 ! audioconvert ! audiocheblimit mode=high-pass cutoff=150 poles=4 ! audiodynamic mode=expander threshold=0.03 ratio=10.0 characteristics=soft-knee ! audioconvert ! volume volume=1.2 ! alsasink device=plug:dmix_speaker sync=false buffer-time=500 latency-time=250 blocksize=16
EOP

if chmod 666 /tmp/jbl_pipeline 2>>"$LOG_FILE"; then
    log "OK" "Pipeline guardado y permisos aplicados a /tmp/jbl_pipeline."
else
    log "WARNING" "No se pudieron cambiar los permisos de /tmp/jbl_pipeline."
fi

log "INFO" "Paso 7: Reiniciando servicio de audio loopback-tampermonkey..."
doas killall -9 gst-launch-1.0 2>>"$LOG_FILE" || true

if doas service loopback-tampermonkey restart >>"$LOG_FILE" 2>&1; then
    log "OK" "Servicio loopback-tampermonkey reiniciado correctamente."
else
    log "ERROR" "Fallo al reiniciar el servicio loopback-tampermonkey."
fi

log "OK" "Proceso finalizado. Audio configurado a USB Wireless JBL Quantum350 (Filtro Anti-Ruido Activo ~0.5ms Latencia)."
log "INFO" "Puedes consultar los logs detallados en: $LOG_FILE"
echo "[OK] Audio configurado a USB Wireless JBL Quantum350 (Filtro Anti-Ruido Activo ~0.5ms Latencia)"
echo "[INFO] Log guardado en $LOG_FILE"
