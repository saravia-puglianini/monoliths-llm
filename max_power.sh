#!/bin/sh
# Script para activar el modo de Máximo Poder en el procesador (Manual)

if command -v tlp >/dev/null 2>&1 || [ -x /usr/sbin/tlp ] || [ -x /usr/bin/tlp ]; then
    echo "[+] TLP detectado en el sistema."
    echo "[+] Activando modo de MÁXIMA POTENCIA..."
    
    # Aplicar modo performance en gobernador y EPP
    echo performance | doas tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    echo performance | doas tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null 2>&1
    
    # Habilitar Turbo Boost y 100% rendimiento P-State
    echo 0 | doas tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1
    echo 100 | doas tee /sys/devices/system/cpu/intel_pstate/max_perf_pct >/dev/null 2>&1
    
    # Comando de TLP si está disponible
    doas tlp ac >/dev/null 2>&1 || true
    
    echo "🔥 MODO MÁXIMA POTENCIA ACTIVADO:"
    echo "   - Gobernador: performance"
    echo "   - Turbo Boost: Habilitado"
    echo "   - Procesador al 100% de capacidad"
else
    echo "[!] ALERTA: TLP no se encuentra instalado en el sistema."
    echo "    Por favor, instala TLP ejecutando el PKGBUILD en ~/optime/tlp/PKGBUILD."
fi
