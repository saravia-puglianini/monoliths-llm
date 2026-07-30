#!/bin/dash

echo '--- MODO HIELO EXTREMO (Para Compilación) ---'

# 1. Desactivar el Turbo Boost (El verdadero secreto)
# Esto evita que el CPU suba de voltajes peligrosos
echo '[1/3] Desactivando Intel/AMD Turbo Boost...'
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null

# 2. Forzar frecuencia mínima
echo '[2/3] Bajando frecuencia al mínimo...'
sudo cpupower frequency-set -u 1.2GHz

# 3. Perfil de ahorro
powerprofilesctl set power-saver

echo '------------------------------------------------'
echo '¡Turbo Boost DESACTIVADO! Ahora puedes compilar sin quemarte.'
echo 'Al reiniciar, el Turbo Boost se reactivará solo.'
