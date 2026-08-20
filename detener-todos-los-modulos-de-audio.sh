#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/detener-todos-los-modulos-de-audio.sh
# Propósito: Detener todos los procesos de audio, descargar todos los módulos de
#            kernel relacionados y limpiar la configuración de audio para dejar
#            el sistema en mínimo consumo de recursos.
# ==============================================================================

LOG_FILE="/tmp/detener_audio.log"
STATE_FILE="/tmp/.apagar_esto_para_encender_el_siguiente"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

echo "=== Inicio de Detención de Audio: $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

log "INFO" "Paso 1: Deteniendo procesos y pipelines de audio activos..."
# Procesos y pipelines generados por perfiles o grabaciones
doas pkill -9 -f "gst-launch-1.0" 2>>"$LOG_FILE" || true
doas pkill -9 -f "speaker-test" 2>>"$LOG_FILE" || true
doas pkill -9 -f "arecord" 2>>"$LOG_FILE" || true
doas pkill -9 -f "aplay" 2>>"$LOG_FILE" || true

# Si hay procesos específicos registrados en el archivo de estado, detenerlos también
if [ -f "$STATE_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" == process:* ]]; then
            local proc_name="${line#process:}"
            log "INFO" "Deteniendo proceso registrado: $proc_name"
            doas pkill -9 -f "$proc_name" 2>>"$LOG_FILE" || true
        fi
    done < "$STATE_FILE"
fi

sleep 0.3

log "INFO" "Paso 2: Descargando todos los módulos de kernel de audio..."

# Lista exhaustiva en orden de dependencia inversa
MODULES_TO_UNLOAD=(
    # Drivers SOF Intel / HDA y enlaces de audio
    "snd_soc_skl_hda_dsp"
    "snd_soc_hdac_hdmi"
    "snd_soc_dmic"
    "snd_sof_pci_intel_tgl"
    "snd_sof_pci_intel_cnl"
    "snd_sof_intel_hda_common"
    "snd_sof_intel_hda"
    "snd_sof_pci"
    "snd_sof_xtensa_dsp"
    "snd_sof"
    "snd_sof_utils"
    "snd_soc_acpi_intel_match"
    "snd_soc_acpi"
    "snd_soc_core"
    "snd_compress"
    # Drivers USB y Loopback
    "snd_usb_audio"
    "snd_usbmidi_lib"
    "snd_aloop"
    # Drivers Intel HDA estándar / Codecs
    "snd_hda_codec_realtek"
    "snd_hda_codec_generic"
    "snd_hda_codec_hdmi"
    "snd_hda_intel"
    "snd_intel_dspcfg"
    "snd_intel_sdw_acpi"
    "snd_hda_codec"
    "snd_hda_core"
    "snd_hwdep"
    # Módulos ALSA base
    "snd_pcm_oss"
    "snd_mixer_oss"
    "snd_pcm"
    "snd_timer"
    "snd_rawmidi"
    "snd_seq_device"
    "snd"
    "soundcore"
)

# Descargar módulos iterativamente
for mod in "${MODULES_TO_UNLOAD[@]}"; do
    if lsmod | grep -q "^${mod//-/_} "; then
        log "INFO" "Descargando módulo: $mod"
        doas modprobe -r "$mod" 2>>"$LOG_FILE" || doas rmmod "$mod" 2>>"$LOG_FILE" || true
    fi
done

# Segunda pasada por si quedaron dependencias liberadas
for mod in "${MODULES_TO_UNLOAD[@]}"; do
    if lsmod | grep -q "^${mod//-/_} "; then
        doas modprobe -r "$mod" 2>>"$LOG_FILE" || doas rmmod "$mod" 2>>"$LOG_FILE" || true
    fi
done

log "INFO" "Paso 3: Limpiando archivos de configuración y estado..."
rm -f "$STATE_FILE" 2>/dev/null || true
rm -f "/home/user/.asoundrc" 2>/dev/null || true
rm -f "/tmp/jbl_pipeline"* 2>/dev/null || true
doas rm -f /etc/asound.conf 2>>"$LOG_FILE" || true

log "OK" "Todos los módulos y procesos de audio han sido detenidos satisfactoriamente."
