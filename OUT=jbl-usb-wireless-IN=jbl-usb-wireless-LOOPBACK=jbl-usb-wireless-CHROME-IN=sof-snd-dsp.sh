#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless-CHROME-IN=sof-snd-dsp.sh
# Perfil: Salida JBL + Entrada JBL + Loopback/Monitoreo en Tiempo Real (~0.5ms)
# ==============================================================================

LOG_FILE="/tmp/out_jbl_in_jbl_loopback_jbl.log"
STATE_FILE="/tmp/.apagar_esto_para_encender_el_siguiente"

REQUIRED_MODULES=("snd-usb-audio" "snd-aloop" "snd_soc_skl_hda_dsp" "snd_sof_pci_intel_tgl" "snd_hda_intel")
REQUIRED_PROCESSES=("gst-launch-1.0")

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

echo "=== Inicio de Ejecución: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless ($(date '+%Y-%m-%d %H:%M:%S')) ===" > "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Ejecutar limpieza del estado previo
cleanup_previous_state

log "INFO" "Paso 2: Asegurando dsp_driver=3 y cargando módulos SOF, Loopback y JBL..."
if [ -d /etc/modprobe.d ]; then
    echo "options snd-intel-dspcfg dsp_driver=3" | doas tee /etc/modprobe.d/alsa-legacy.conf >/dev/null
fi

doas modprobe snd-usb-audio lowlatency=1 implicit_fb=0 2>>"$LOG_FILE" || true
doas modprobe snd-aloop 2>>"$LOG_FILE" || true
doas modprobe snd_sof_pci_intel_tgl 2>>"$LOG_FILE" || true
doas modprobe snd_soc_skl_hda_dsp 2>>"$LOG_FILE" || true
doas modprobe snd_hda_intel 2>>"$LOG_FILE" || true

sleep 0.4

# Detectar nombre de tarjeta interna en ALSA
CARD_NAME="sofhdadsp"
if grep -q -i "sofhdadsp" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sofhdadsp"
elif grep -q -i "sof" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sof-hda-dsp"
elif grep -q -i "pch" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="PCH"
fi

MIC_DEV="6"
if arecord -l 2>/dev/null | grep -q "card.*${CARD_NAME}.*device 6"; then
    MIC_DEV="6"
else
    MIC_DEV="0"
fi
log "INFO" "Micrófono Laptop SOF detectado en: hw:${CARD_NAME},${MIC_DEV}"

# Silenciar altavoces internos si el módulo SOF estuvo activo
amixer -c "${CARD_NAME}" set Master mute >/dev/null 2>&1 || amixer -c 0 set Master mute >/dev/null 2>&1 || true
amixer -c "${CARD_NAME}" set Capture unmute 100% 2>/dev/null || true
 amixer -c "${CARD_NAME}" sset 'Dmic0' 100% unmute cap 2>/dev/null || true
 amixer -c "${CARD_NAME}" sset 'Dmic1 2nd' 100% unmute cap 2>/dev/null || true
 amixer -c "${CARD_NAME}" sset 'PGA2.0 2 Master' 100% unmute cap 2>/dev/null || true >/dev/null 2>&1 || true

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
            --title="Audio USB Wireless Loopback" \
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

cat << EOC > "$ASOUND_USER"
# ==============================================================================
# Configuración ALSA de Usuario: OUT=jbl + IN=jbl + LOOPBACK=jbl
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

pcm.dsnoop_sof {
    type dsnoop
    ipc_key 1026
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:${CARD_NAME},${MIC_DEV}"
        rate 48000
        channels 2
        period_size 1024
        buffer_size 4096
    }
}

pcm.microfono_laptop {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.sof_snd_dsp {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.chrome_in_sof_snd_dsp {
    type plug
    slave.pcm "dsnoop_sof"
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

log "INFO" "Paso 6: Ajustando niveles de volumen del micrófono JBL al 100%..."
amixer -c Wireless sset Mic 100% unmute 2>>"$LOG_FILE" || true
amixer -c Wireless sset Headphone 100% unmute 2>>"$LOG_FILE" || amixer -c Wireless set Master 100% unmute 2>>"$LOG_FILE" || true

log "INFO" "Paso 7: Guardando pipeline en /tmp/jbl_pipeline..."
cat << 'EOP' > /tmp/jbl_pipeline
alsasrc device=plug:dsnoop_mic buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=1 ! alsasink device=plug:dmix_speaker sync=false buffer-time=500 latency-time=250 blocksize=16
EOP
chmod 666 /tmp/jbl_pipeline 2>/dev/null || true

log "INFO" "Paso 8: Iniciando loopback en tiempo real (~0.5ms latencia)..."
nohup gst-launch-1.0 -q alsasrc device=plug:dsnoop_mic buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=1 ! alsasink device=plug:dmix_speaker sync=false buffer-time=500 latency-time=250 blocksize=16 </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
sleep 0.5

if pgrep -f "gst-launch-1.0" >/dev/null 2>&1; then
    log "OK" "Loopback en tiempo real iniciado exitosamente (PID: $(pgrep -f "gst-launch-1.0" | tr '\n' ' '))."
else
    log "WARNING" "No se detectó el proceso gst-launch-1.0 en ejecución."
fi

# Guardar estado actual para el siguiente script
save_current_state

log "OK" "Perfil activo: OUT=jbl-usb-wireless | IN=jbl-usb-wireless | LOOPBACK=jbl-usb-wireless"
log "INFO" "Logs guardados en $LOG_FILE"
