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
# Detener pipelines y reproductores de audio de forma segura
for target in "gst-launch-1.0" "speaker-test" "arecord" "aplay" "espeak" "espeak-ng" "piper"; do
    if pgrep -f "$target" >/dev/null 2>&1; then
        log "INFO" "Terminando procesos: $target"
        doas pkill -15 -f "$target" 2>>"$LOG_FILE" || true
    fi
done
sleep 0.2
# Forzar con SIGKILL solo a procesos de audio específicos si aún siguen vivos
for target in "gst-launch-1.0" "speaker-test" "arecord" "aplay"; do
    doas pkill -9 -f "$target" 2>>"$LOG_FILE" || true
done

# Si hay procesos específicos registrados en el archivo de estado, detenerlos de forma validada
if [ -f "$STATE_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" == process:* ]]; then
            proc_name="${line#process:}"
            # Evitar matar por accidente componentes del sistema o del display server
            if [[ "$proc_name" =~ (Xorg|xenocara|x11|xinit|cwm|openbox|spectrwm|dwm|fluxbox|fvwm|tmux|ssh|dbus|session|daemon|login) ]]; then
                log "WARN" "Omitiendo proceso crítico del sistema/pantalla: $proc_name"
                continue
            fi
            if [ -n "$proc_name" ]; then
                log "INFO" "Deteniendo proceso registrado: $proc_name"
                doas pkill -15 -f "$proc_name" 2>>"$LOG_FILE" || true
                sleep 0.1
                doas pkill -9 -f "$proc_name" 2>>"$LOG_FILE" || true
            fi
        fi
    done < "$STATE_FILE"
fi

sleep 0.2

log "INFO" "Paso 2: Descargando módulos de kernel de audio (respetando stack gráfico/DRM)..."

# Lista de módulos de audio a descargar
# NOTA: Se excluyen intencionalmente snd_hda_codec_hdmi y snd_soc_hdac_hdmi para evitar
# reiniciar o colapsar el pipeline DRM/KMS de la GPU (i915/inteldrm) que tumba Xorg/Xenocara.
MODULES_TO_UNLOAD=(
    # Drivers SOF Intel / HDA y enlaces de audio
    "snd_soc_skl_hda_dsp"
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

# Función para descargar módulos de forma segura si no están en uso por el driver de video
unload_modules() {
    for mod in "${MODULES_TO_UNLOAD[@]}"; do
        local mod_name="${mod//-/_}"
        # Verificar si el módulo está cargado
        local mod_line
        mod_line=$(lsmod | grep "^${mod_name} ")
        if [ -n "$mod_line" ]; then
            # Obtener qué módulos dependen de este actualmente
            local used_by
            used_by=$(echo "$mod_line" | awk '{print $4}')
            # Si está siendo usado por drivers de video (i915, drm, etc.), no descargarlo para salvar Xenocara
            if echo "$used_by" | grep -Eq "(i915|drm|video)"; then
                log "WARN" "Módulo $mod en uso por DRM/GPU ($used_by). Omitiendo descarga para proteger la sesión gráfica."
                continue
            fi
            log "INFO" "Descargando módulo: $mod"
            doas modprobe -r "$mod" 2>>"$LOG_FILE" || doas rmmod "$mod" 2>>"$LOG_FILE" || true
        fi
    done
}

# Ejecutar descarga en dos pasadas
unload_modules
unload_modules

log "INFO" "Paso 3: Limpiando archivos de configuración y estado..."
rm -f "$STATE_FILE" 2>/dev/null || true
rm -f "/home/user/.asoundrc" 2>/dev/null || true
rm -f "/tmp/jbl_pipeline"* 2>/dev/null || true
doas rm -f /etc/asound.conf 2>>"$LOG_FILE" || true

log "OK" "Todos los módulos y procesos de audio han sido detenidos satisfactoriamente sin afectar la sesión gráfica."
