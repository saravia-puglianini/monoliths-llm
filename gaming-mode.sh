#!/usr/bin/env bash

# ============================================
# MAX PERFORMANCE / GAMING MODE FOR LINUX
# Intel CPU + cpufreq/intel_pstate
# ============================================

set -e

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta este script como root"
    echo "Ejemplo: doas ./gaming-mode.sh"
    exit 1
fi

echo "====================================="
echo " ACTIVANDO MODO GAMER / PERFORMANCE "
echo "====================================="

# --------------------------------------
# CPU GOVERNOR -> PERFORMANCE
# --------------------------------------
echo
echo "[+] Configurando governor performance..."

for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -f "$gov" ]] && echo performance > "$gov"
done

# --------------------------------------
# ACTIVAR TURBO BOOST
# --------------------------------------
if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    echo
    echo "[+] Activando Turbo Boost..."
    echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
fi

# --------------------------------------
# POWER LIMITS (PL1/PL2)
# --------------------------------------
if [[ -d /sys/class/powercap/intel-rapl:0 ]]; then
    echo
    echo "[+] Ajustando power limits PL1/PL2..."
    echo 45000000 | doas tee /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw   # PL1 45W sostenido
    echo 60000000 | doas tee /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw   # PL2 60W turbo corto
fi

# --------------------------------------
# MAX CPU FREQUENCY
# --------------------------------------
echo
echo "[+] Eliminando límites de frecuencia..."

MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)

for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
    [[ -f "$f" ]] && echo "$MAX_FREQ" > "$f"
done

# --------------------------------------
# MIN CPU FREQUENCY
# --------------------------------------
echo
echo "[+] Ajustando frecuencia mínima..."

BOOST_MIN=$((MAX_FREQ * 70 / 100))

for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
    [[ -f "$f" ]] && echo "$BOOST_MIN" > "$f"
done

# --------------------------------------
# DESACTIVAR POWERSAVE PCIe
# --------------------------------------
if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
    echo
    echo "[+] Desactivando ASPM powersave..."
    echo performance > /sys/module/pcie_aspm/parameters/policy || true
fi

# --------------------------------------
# DESACTIVAR AUTOSUSPEND USB
# --------------------------------------
echo
echo "[+] Desactivando USB autosuspend..."

for usb in /sys/bus/usb/devices/*/power/control; do
    [[ -f "$usb" ]] && echo on > "$usb" || true
done

# --------------------------------------
# DESACTIVAR TLP SI EXISTE
# --------------------------------------
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet tlp; then
        echo
        echo "[+] Desactivando TLP..."
        systemctl stop tlp
    fi
fi

# --------------------------------------
# I/O SCHEDULER
# --------------------------------------
echo
echo "[+] Ajustando I/O scheduler..."

for sched in /sys/block/*/queue/scheduler; do
    if grep -q mq-deadline "$sched"; then
        echo mq-deadline > "$sched"
    fi
done

# --------------------------------------
# SWAPPINESS
# --------------------------------------
echo
echo "[+] Ajustando swappiness..."

sysctl -w vm.swappiness=10 >/dev/null

# --------------------------------------
# TRANSPARENT HUGEPAGES
# --------------------------------------
if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
    echo
    echo "[+] Activando Transparent Huge Pages..."
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
fi

# --------------------------------------
# INFORMACIÓN FINAL
# --------------------------------------
echo
echo "====================================="
echo "   MODO GAMER ACTIVADO"
echo "====================================="
echo

echo "Governor:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo
echo "Turbo:"
cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true

echo
echo "Power limits (PL1/PL2):"
cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw

echo
echo "Frecuencia máxima:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

echo
echo "Frecuencia mínima:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

echo
echo "Frecuencia actual:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

echo
echo "Listo."