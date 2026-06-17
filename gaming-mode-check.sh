#!/usr/bin/env bash

# ==========================================
# CPU BOOST CHECKER
# Detecta si Turbo Boost está funcionando
# ==========================================

clear

echo "========================================"
echo "         CPU BOOST CHECKER"
echo "========================================"
echo

# ------------------------------------------
# OBTENER FRECUENCIAS
# ------------------------------------------

MAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
MIN=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)
CUR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)

MAX_GHZ=$(awk "BEGIN {printf \"%.2f\", $MAX/1000000}")
MIN_GHZ=$(awk "BEGIN {printf \"%.2f\", $MIN/1000000}")
CUR_GHZ=$(awk "BEGIN {printf \"%.2f\", $CUR/1000000}")

# ------------------------------------------
# TURBO STATUS
# ------------------------------------------

if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)

    if [[ "$TURBO" == "0" ]]; then
        TURBO_STATUS="ACTIVADO"
    else
        TURBO_STATUS="DESACTIVADO"
    fi
else
    TURBO_STATUS="NO DISPONIBLE"
fi

# ------------------------------------------
# CPU LOAD
# ------------------------------------------

LOAD=$(uptime | awk -F'load average:' '{ print $2 }')

# ------------------------------------------
# MOSTRAR INFO
# ------------------------------------------

echo "Turbo Boost : $TURBO_STATUS"
echo
echo "Frecuencia mínima : ${MIN_GHZ} GHz"
echo "Frecuencia máxima : ${MAX_GHZ} GHz"
echo "Frecuencia actual : ${CUR_GHZ} GHz"
echo
echo "Load average:$LOAD"
echo

# ------------------------------------------
# DETECTAR BOOST
# ------------------------------------------

BOOST_THRESHOLD=$((MAX * 85 / 100))

if (( CUR >= BOOST_THRESHOLD )); then
    echo "🔥 EL CPU ESTÁ BOOSTEANDO"
elif (( CUR >= MIN )); then
    echo "⚡ CPU EN ALTO RENDIMIENTO"
else
    echo "💤 CPU RELAJADO / IDLE"
fi

echo
echo "========================================"