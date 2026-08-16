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
modprobe intel_rapl_common 2>/dev/null || true
modprobe intel_rapl_msr 2>/dev/null || true

if [[ -d /sys/class/powercap/intel-rapl:0 ]]; then
    echo
    echo "[+] Ajustando power limits PL1/PL2..."
    [[ -f /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw ]] && echo 45000000 | tee /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw >/dev/null   # PL1 45W sostenido
    [[ -f /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw ]] && echo 60000000 | tee /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw >/dev/null   # PL2 60W turbo corto
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

if command -v sysctl >/dev/null 2>&1; then
    sysctl -w vm.swappiness=10 >/dev/null
elif [[ -f /proc/sys/vm/swappiness ]]; then
    echo 10 > /proc/sys/vm/swappiness
fi

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
echo "No_turbo:"
cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true

echo
echo "Power limits (PL1/PL2):"
SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "generic")

if [[ "$SYS_VENDOR" == *hp* ]]; then
    if [[ -f /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw ]]; then
        cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
    else
        echo "PL1: no disponible"
    fi
    if [[ -f /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw ]]; then
        cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw
    else
        echo "PL2: no disponible"
    fi
elif [[ "$SYS_VENDOR" == *asus* ]]; then
    if [[ -f /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw ]]; then
        PL1=$(cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw)
        PL2=$(cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw)
        awk "BEGIN {printf \"%.0f W\n%.0f W\n\", $PL1/1000000, $PL2/1000000}"
    else
        echo "No disponible en este hardware/driver"
    fi
else
    if [[ -f /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw ]]; then
        cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
    else
        echo "PL1: no disponible"
    fi
    if [[ -f /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw ]]; then
        cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw
    else
        echo "PL2: no disponible"
    fi
fi

echo
echo "Frecuencia máxima:"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ]]; then
    awk "BEGIN {printf \"%.2f GHz\n\", $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)/1000000}"
fi

echo
echo "Frecuencia mínima:"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq ]]; then
    awk "BEGIN {printf \"%.2f GHz\n\", $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)/1000000}"
fi

echo
echo "Frecuencia actual:"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
    awk "BEGIN {printf \"%.2f GHz\n\", $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)/1000000}"
fi

echo
echo "Listo."