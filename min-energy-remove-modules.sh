#!/usr/bin/env bash

# ==============================================================================
# MIN ENERGY / ULTRA POWER SAVE - REMOVE KERNEL MODULES & HARDWARE POWER OFF
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta este script como root"
    echo "Ejemplo: doas $0"
    exit 1
fi

echo "====================================================="
echo "   ACTIVANDO PERFIL DE MÍNIMO CONSUMO Y ENERGÍA     "
echo "====================================================="

# ------------------------------------------------------------------------------
# 1. PARAR PROCESOS QUE USEN DISPOSITIVOS INNECESARIOS
# ------------------------------------------------------------------------------
echo
echo "[+] Deteniendo procesos en segundo plano innecesarios..."
pkill -9 blueman-applet 2>/dev/null || true
pkill -9 blueman-manager 2>/dev/null || true
pkill -9 bluetoothd 2>/dev/null || true
pkill -9 obexd 2>/dev/null || true
pkill -9 -f "gst-launch-1.0" 2>/dev/null || true
pkill -9 -f "speaker-test" 2>/dev/null || true
pkill -9 -f "arecord" 2>/dev/null || true
pkill -9 -f "aplay" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. BLOQUEO POR RFKILL (BLUETOOTH)
# ------------------------------------------------------------------------------
if command -v rfkill >/dev/null 2>&1; then
    echo
    echo "[+] Apagando radio Bluetooth mediante rfkill..."
    rfkill block bluetooth 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 3. DESCARGAR MÓDULOS DE KERNEL (IGUALES A MAX_ENERGY + BLUETOOTH + EXTRAS)
# ------------------------------------------------------------------------------
echo
echo "[+] Descargando módulos de kernel innecesarios..."

# Módulos Bluetooth
BT_MODULES=(
    "bnep"
    "btusb"
    "btintel"
    "btbcm"
    "btrtl"
    "btmtk"
    "bluetooth"
    "ecdh_generic"
)

# Tarjetas WiFi secundarias/antiguas (Atheros)
ATH_MODULES=(
    "ath9k_htc"
    "ath9k"
    "ath9k_common"
    "ath9k_hw"
    "ath"
)

# Cámara / Webcam (uvcvideo y subsistema v4l2)
CAMERA_MODULES=(
    "uvcvideo"
    "uvc"
    "videobuf2_vmalloc"
    "videobuf2_memops"
    "videobuf2_v4l2"
    "videobuf2_common"
    "videodev"
    "mc"
)

# Lectores de Tarjetas SD / MMC (Realtek RTSX)
SDCARD_MODULES=(
    "rtsx_pci_sdmmc"
    "rtsx_pci"
)

# Módulos de Audio (SOF, HDA, Codecs, USB Audio)
AUDIO_MODULES=(
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
    "snd_usb_audio"
    "snd_usbmidi_lib"
    "snd_aloop"
    "snd_hda_codec_realtek"
    "snd_hda_codec_generic"
    "snd_hda_codec_hdmi"
    "snd_hda_intel"
    "snd_intel_dspcfg"
    "snd_intel_sdw_acpi"
    "snd_hda_codec"
    "snd_hda_core"
    "snd_hwdep"
    "snd_pcm_oss"
    "snd_mixer_oss"
    "snd_pcm"
    "snd_timer"
    "snd_rawmidi"
    "snd_seq_device"
    "snd"
    "soundcore"
)

ALL_MODULES=(
    "${BT_MODULES[@]}"
    "${ATH_MODULES[@]}"
    "${CAMERA_MODULES[@]}"
    "${SDCARD_MODULES[@]}"
    "${AUDIO_MODULES[@]}"
)

for mod in "${ALL_MODULES[@]}"; do
    if lsmod | grep -q "^${mod//-/_} "; then
        modprobe -r "$mod" 2>/dev/null || rmmod "$mod" 2>/dev/null || true
    fi
done

# Segunda pasada para dependencias liberadas
for mod in "${ALL_MODULES[@]}"; do
    if lsmod | grep -q "^${mod//-/_} "; then
        modprobe -r "$mod" 2>/dev/null || rmmod "$mod" 2>/dev/null || true
    fi
done

# 4. Journaling (jbd2) y Sistema de Archivos (ext4)
if ! mount | grep -E -q '\btype (ext3|ext4)\b'; then
    echo "[+] Verificado: No hay particiones ext3/ext4 montadas (trabajando en ext2)."
    if lsmod | grep -q "^jbd2 "; then
        modprobe -r jbd2 2>/dev/null || rmmod jbd2 2>/dev/null || true
    fi
    if lsmod | grep -q "^ext4 " && [ "$(awk '$1=="ext4"{print $3}' /proc/modules)" = "0" ]; then
        modprobe -r ext4 2>/dev/null || rmmod ext4 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 4. AJUSTES DE CPU Y ENERGÍA (POWERSAVE, NO TURBO, EPP, TLP)
# ------------------------------------------------------------------------------
echo
echo "[+] Configurando governor powersave y EPP power..."
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -f "$gov" ]] && echo powersave > "$gov" 2>/dev/null || true
done

for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [[ -f "$epp" ]] && echo power > "$epp" 2>/dev/null || true
done

# Desactivar Turbo Boost
if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
fi

# Activar ASPM Powersave en PCIe
if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
    echo
    echo "[+] Activando PCIe ASPM powersave..."
    echo powersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
fi

# Activar USB Autosuspend
echo
echo "[+] Activando USB autosuspend..."
for usb in /sys/bus/usb/devices/*/power/control; do
    [[ -f "$usb" ]] && echo auto > "$usb" 2>/dev/null || true
done

# Activar ahorro de energía en PCI
for pci in /sys/bus/pci/devices/*/power/control; do
    [[ -f "$pci" ]] && echo auto > "$pci" 2>/dev/null || true
done

# Iniciar / actualizar TLP en modo batería si existe
if command -v tlp >/dev/null 2>&1; then
    echo
    echo "[+] Aplicando perfil TLP bat..."
    tlp bat >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# INFORMACIÓN FINAL
# ------------------------------------------------------------------------------
echo
echo "====================================================="
echo "   MODO MIN_ENERGY ACTIVADO EXITOSAMENTE"
echo "====================================================="
echo
echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
echo "Turbo Boost: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null | sed 's/1/DESACTIVADO/;s/0/ACTIVADO/' || echo 'N/A')"
echo "Bluetooth: $(rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' && echo 'DESACTIVADO (Soft blocked)' || echo 'DESCONECTADO / BLOQUEADO')"
echo
echo "Listo."
