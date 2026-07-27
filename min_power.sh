#!/bin/sh
# Script para activar el modo de Mínimo Consumo en el procesador (Manual)

if command -v tlp >/dev/null 2>&1 || [ -x /usr/sbin/tlp ] || [ -x /usr/bin/tlp ]; then
    echo "[+] TLP detectado en el sistema."
    echo "[+] Activando modo de MÍNIMO CONSUMO DE ENERGÍA..."
    
    # Aplicar modo powersave y política de bajo consumo
    echo powersave | doas tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    echo power | doas tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null 2>&1
    
    # Deshabilitar Turbo Boost para minimizar temperatura
    echo 1 | doas tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1
    
    # Ejecutar TLP start
    doas tlp start >/dev/null 2>&1 || true
    
    echo "🍃 MODO MÍNIMO CONSUMO ACTIVADO:"
    echo "   - Gobernador: powersave"
    echo "   - EPP: power"
    echo "   - Turbo Boost: Deshabilitado"
    echo "   - Consumo mínimo de batería y bajo calor"
else
    echo "[!] ALERTA: TLP no se encuentra instalado en el sistema."
    echo "    Por favor, instala TLP ejecutando el PKGBUILD en ~/optime/tlp/PKGBUILD."
fi
