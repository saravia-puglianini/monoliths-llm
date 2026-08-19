#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh
# Perfil: Salida JBL Quantum 350 + Entrada Micrófono JBL con Filtro Anti-Ruido DSP
# ==============================================================================

LOG_FILE="/tmp/out_jbl_in_jbl_filter.log"
STATE_FILE="/tmp/.apagar_esto_para_encender_el_siguiente"

REQUIRED_MODULES=("snd-usb-audio")
REQUIRED_PROCESSES=()

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

is_required_module() {
    local target="$1"
    for m in "${REQUIRED_MODULES[@]}"; do
        [ "$m" = "$target" ] && return 0
    done
    return 1
}

cleanup_previous_state() {
    log "INFO" "Paso 1: Leyendo $STATE_FILE para apagar módulos y procesos del perfil anterior..."
    doas pkill -9 -f "gst-launch-1.0" 2>>"$LOG_FILE" || true
    sleep 0.2

    if [ -f "$STATE_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            if [[ "$line" == process:* ]]; then
                local proc_name="${line#process:}"
                log "INFO" "Deteniendo proceso anterior: $proc_name"
                doas pkill -9 -f "$proc_name" 2>>"$LOG_FILE" || true
            elif [[ "$line" == module:* ]]; then
                local mod_name="${line#module:}"
                if ! is_required_module "$mod_name"; then
                    log "INFO" "Descargando módulo anterior no necesario: $mod_name"
                    doas modprobe -r "$mod_name" 2>>"$LOG_FILE" || doas rmmod "$mod_name" 2>>"$LOG_FILE" || true
                else
                    log "INFO" "Manteniendo módulo necesario: $mod_name"
                fi
            fi
        done < "$STATE_FILE"
    else
        log "INFO" "No existe $STATE_FILE previo. Estado inicial limpio."
    fi
}

save_current_state() {
    log "INFO" "Registrando módulos y procesos activos en $STATE_FILE..."
    {
        echo "# Perfil activo generado por $(basename "$0") el $(date '+%Y-%m-%d %H:%M:%S')"
        for mod in "${REQUIRED_MODULES[@]}"; do
            echo "module:$mod"
        done
        for proc in "${REQUIRED_PROCESSES[@]}"; do
            echo "process:$proc"
        done
    } > "$STATE_FILE"
    chmod 666 "$STATE_FILE" 2>/dev/null || true
    log "OK" "Estado guardado en $STATE_FILE"
}

echo "=== Inicio de Ejecución: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER ($(date '+%Y-%m-%d %H:%M:%S')) ===" > "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Ejecutar limpieza del estado previo
cleanup_previous_state

log "INFO" "Paso 2: Cargando módulo snd-usb-audio con baja latencia..."
if doas modprobe snd-usb-audio lowlatency=1 implicit_fb=0 2>>"$LOG_FILE"; then
    log "OK" "Módulo snd-usb-audio cargado correctamente."
else
    log "WARNING" "Aviso al cargar snd-usb-audio."
fi

amixer -c sofhdadsp set Master mute >/dev/null 2>&1 || amixer -c 0 set Master mute >/dev/null 2>&1 || true

sleep 0.4

log "INFO" "Paso 3: Validando conexión del dispositivo JBL Quantum 350..."
CONNECTED=false
if lsusb 2>/dev/null | grep -i -E "0ecb:206b|JBL|Quantum350|Wireless" >/dev/null; then
    CONNECTED=true
elif grep -q -i "wireless" /proc/asound/cards 2>/dev/null; then
    CONNECTED=true
fi

if [ "$CONNECTED" = false ]; then
    log "ERROR" "No se detectó el dispositivo USB Audio Wireless JBL."
    if command -v yad >/dev/null 2>&1; then
        yad --image=dialog-warning \
            --title="Audio USB Wireless Filter" \
            --text="No se detectó el dispositivo USB Audio Wireless JBL" \
            --button=GTK_STOCK_OK:0 \
            --width=350 --center 2>/dev/null &
    fi
    exit 1
else
    log "OK" "Dispositivo JBL Quantum 350 detectado correctamente."
fi

log "INFO" "Paso 4: Eliminando /etc/asound.conf..."
doas rm -f /etc/asound.conf 2>>"$LOG_FILE" || true

ASOUND_USER="/home/user/.asoundrc"
log "INFO" "Paso 5: Escribiendo configuración limpia en ${ASOUND_USER}..."
rm -f "$ASOUND_USER" 2>/dev/null || true

cat << 'EOC' > "$ASOUND_USER"
# ==============================================================================
# Configuración ALSA de Usuario: OUT=jbl-usb-wireless + IN=jbl-usb-wireless-FILTER
# ==============================================================================

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

pcm.salida_jbl {
    type plug
    slave.pcm "dmix_speaker"
}

pcm.entrada_buena_jbl {
    type plug
    slave.pcm "dsnoop_mic"
}

pcm.entrada_buena_16k_jbl {
    type plug
    slave {
        pcm "dsnoop_mic"
        rate 16000
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

chmod 644 "$ASOUND_USER" 2>/dev/null || true
log "OK" "${ASOUND_USER} actualizado correctamente."

log "INFO" "Paso 6: Configurando pipeline de filtro anti-ruido en /tmp/jbl_pipeline..."
cat << 'EOP' > /tmp/jbl_pipeline
alsasrc device=plug:dsnoop_mic buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=1 ! audioconvert ! audiocheblimit mode=high-pass cutoff=150 poles=4 ! audiodynamic mode=expander threshold=0.03 ratio=10.0 characteristics=soft-knee ! audioconvert ! volume volume=1.2 ! alsasink device=plug:dmix_speaker sync=false buffer-time=500 latency-time=250 blocksize=16
EOP
chmod 666 /tmp/jbl_pipeline 2>/dev/null || true

log "INFO" "Paso 7: Ajustando niveles de volumen del micrófono JBL al 100%..."
amixer -c Wireless sset Mic 100% unmute 2>>"$LOG_FILE" || true
amixer -c Wireless sset Headphone 100% unmute 2>>"$LOG_FILE" || amixer -c Wireless set Master 100% unmute 2>>"$LOG_FILE" || true

# Guardar estado actual para el siguiente script
save_current_state

log "OK" "Perfil activo: OUT=jbl-usb-wireless | IN=jbl-usb-wireless-FILTER"
log "INFO" "Logs guardados en $LOG_FILE"
