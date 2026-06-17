#!/bin/dash

echo '--- MODO HIELO EXTREMO HP (Para Compilación) ---'

# 1. Desactivar el Turbo Boost
# Esto evita que el procesador suba de voltajes y temperaturas pico
echo '[1/3] Desactivando Intel Turbo Boost...'
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    echo 1 | doas tee /sys/devices/system/cpu/intel_pstate/no_turbo
else
    echo "No se encontró control de Turbo Boost en /sys. Saltando..."
fi

# 2. Limitar el rendimiento máximo (Equivalente a bajar frecuencia fija)
# En Intel 12va Gen, limitar el porcentaje es más efectivo que cpupower si no está instalado
echo '[2/3] Limitando potencia máxima al 50%...'
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
    echo 50 | doas tee /sys/devices/system/cpu/intel_pstate/max_perf_pct
else
    echo "No se encontró control de max_perf_pct. Saltando..."
fi

# 3. Perfil de ahorro de energía via system76/gnome power-profiles-daemon
echo '[3/3] Activando perfil Power Saver...'
powerprofilesctl set power-saver

echo '------------------------------------------------'
echo '¡HP enfriada! Turbo desactivado y potencia limitada al 50%.'
echo 'Ahora puedes compilar sin que los ventiladores suenen como un avión.'
echo 'Al reiniciar, el sistema volverá a sus valores normales.'
