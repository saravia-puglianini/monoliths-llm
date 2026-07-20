#!/bin/bash

# Auto-escalate using doas if not running as root
if [ "$EUID" -ne 0 ]; then
  echo "Escalating privileges using doas..."
  exec doas "$0" "$@"
fi

echo "Setting power saving mode..."

# Disable Intel Turbo Boost
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
  echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
  echo "- Turbo Boost: Disabled"
fi

# Limit maximum performance to 50%
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
  echo 25 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
  echo "- Max CPU Performance Limit: 25%"
fi

# Set scaling governor to powersave for all CPU cores
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  if [ -f "$gov" ]; then
    echo powersave > "$gov"
  fi
done
echo "- CPU Governor: powersave"

# Set EPP (Energy Performance Preference) to power
for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
  if [ -f "$epp" ]; then
    echo power > "$epp"
  fi
done
echo "- Energy Performance Preference: power"

echo "System configured for MINIMUM power / maximum battery life."
