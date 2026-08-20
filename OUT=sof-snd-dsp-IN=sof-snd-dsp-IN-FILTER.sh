#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh
# Perfil: Salida SOF Altavoces + Entrada SOF Micrófono con Filtro Anti-Ruido DSP
# ==============================================================================

LOG_FILE="/tmp/out_sof_in_sof_filter.log"
STATE_FILE="/tmp/.apagar_esto_para_encender_el_siguiente"

REQUIRED_MODULES=("snd_soc_skl_hda_dsp" "snd_sof_pci_intel_tgl" "snd_hda_intel")
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

echo "=== Inicio de Ejecución: OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER ($(date '+%Y-%m-%d %H:%M:%S')) ===" > "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Ejecutar limpieza del estado previo
cleanup_previous_state

log "INFO" "Paso 2: Asegurando configuración en /etc/modprobe.d/alsa-legacy.conf..."
if [ -d /etc/modprobe.d ]; then
    echo "options snd-intel-dspcfg dsp_driver=3" | doas tee /etc/modprobe.d/alsa-legacy.conf >/dev/null
fi

log "INFO" "Paso 3: Cargando módulos del driver SOF Intel bajo demanda..."
for mod in "${REQUIRED_MODULES[@]}"; do
    doas modprobe "$mod" 2>>"$LOG_FILE" || true
done

sleep 0.5

# Detectar nombre de tarjeta interna en ALSA
CARD_NAME="sofhdadsp"
if grep -q -i "sofhdadsp" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sofhdadsp"
elif grep -q -i "sof" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="sof-hda-dsp"
elif grep -q -i "pch" /proc/asound/cards 2>/dev/null; then
    CARD_NAME="PCH"
fi
log "OK" "Tarjeta de audio interno detectada: ${CARD_NAME}"

MIC_DEV="7"
if arecord -l 2>/dev/null | grep -q "card.*${CARD_NAME}.*device 6"; then
    MIC_DEV="7"
else
    MIC_DEV="0"
fi
log "INFO" "Dispositivo de captura seleccionado: hw:${CARD_NAME},${MIC_DEV}"

log "INFO" "Paso 4: Eliminando /etc/asound.conf..."
doas rm -f /etc/asound.conf 2>>"$LOG_FILE" || true

ASOUND_USER="/home/user/.asoundrc"
log "INFO" "Paso 5: Escribiendo configuración limpia con alias de filtro en ${ASOUND_USER}..."
rm -f "$ASOUND_USER" 2>/dev/null || true

cat <<EOC > "$ASOUND_USER"
# ==============================================================================
# Configuración ALSA de Usuario: OUT=sof-snd-dsp + IN=sof-snd-dsp-FILTER
# Generado automáticamente: $(date '+%Y-%m-%d %H:%M:%S')
# ==============================================================================

pcm.dmix_sof {
    type dmix
    ipc_key 1024
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:${CARD_NAME},0"
        rate 48000
        period_size 1024
        buffer_size 4096
    }
}

pcm.dsnoop_sof {
    type dsnoop
    ipc_key 1025
    ipc_key_add_uid false
    ipc_perm 0666
    slave {
        pcm "hw:${CARD_NAME},${MIC_DEV}"
        rate 16000
        channels 2
        period_size 512
        buffer_size 2048
    }
}

pcm.dsnoop_mic {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.microfono_laptop {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.entrada_buena_jbl {
    type plug
    slave.pcm "dsnoop_sof"
}

pcm.entrada_buena_16k_jbl {
    type plug
    slave {
        pcm "dsnoop_sof"
        rate 16000
    }
}

pcm.dmix_speaker {
    type plug
    slave.pcm "dmix_sof"
}

pcm.!default {
    type asym
    playback.pcm "plug:dmix_sof"
    capture.pcm "plug:dsnoop_sof"
}

pcm.!sysdefault {
    type plug
    slave.pcm "default"
}

ctl.microfono_laptop {
    type hw
    card "${CARD_NAME}"
}

ctl.sof_snd_dsp {
    type hw
    card "${CARD_NAME}"
}

ctl.chrome_in_sof_snd_dsp {
    type hw
    card "${CARD_NAME}"
}

ctl.entrada_buena_jbl {
    type hw
    card "Wireless"
}

ctl.entrada_buena_16k_jbl {
    type hw
    card "Wireless"
}

ctl.salida_jbl {
    type hw
    card "Wireless"
}

ctl.!default {
    type hw
    card "${CARD_NAME}"
}
EOC

chmod 644 "$ASOUND_USER" 2>/dev/null || true
log "OK" "${ASOUND_USER} actualizado correctamente."

log "INFO" "Paso 6: Ajustando volumen y desmuteando altavoces/micrófono interno..."
amixer -c "${CARD_NAME}" set Master unmute 100% 2>>"$LOG_FILE" || amixer -c 0 set Master unmute 100% 2>>"$LOG_FILE" || true
amixer -c "${CARD_NAME}" set Speaker unmute 100% 2>>"$LOG_FILE" || true
amixer -c "${CARD_NAME}" set Capture unmute 100% 2>>"$LOG_FILE" || true

log "INFO" "Paso 7: Configurando pipeline de filtro para el micrófono SOF en /tmp/jbl_pipeline..."
cat << 'EOP' > /tmp/jbl_pipeline
alsasrc device=plug:dsnoop_sof buffer-time=500 latency-time=250 blocksize=16 ! audio/x-raw, format=S16LE, rate=48000, channels=2 ! audioconvert ! audiocheblimit mode=high-pass cutoff=150 poles=4 ! audiodynamic mode=expander threshold=0.03 ratio=10.0 characteristics=soft-knee ! audioconvert ! volume volume=1.2 ! alsasink device=plug:dmix_sof sync=false buffer-time=500 latency-time=250 blocksize=16
EOP
chmod 666 /tmp/jbl_pipeline 2>/dev/null || true

# Guardar estado actual para el siguiente script
save_current_state

log "OK" "Perfil activo: OUT=sof-snd-dsp | IN=sof-snd-dsp-FILTER"
log "INFO" "Logs guardados en $LOG_FILE"
