#!/bin/bash

# Auto-escalate using doas if not running as root
if [ "$EUID" -ne 0 ]; then
  echo "Escalating privileges using doas..."
  exec doas "$0" "$@"
fi

echo "Setting maximum performance mode..."

# Enable Intel Turbo Boost
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
  echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
  echo "- Turbo Boost: Enabled"
fi

# Set maximum performance to 100%
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
  echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
  echo "- Max CPU Performance Limit: 100%"
fi

# Set scaling governor to performance for all CPU cores
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  if [ -f "$gov" ]; then
    echo performance > "$gov"
  fi
done
echo "- CPU Governor: performance"

# Set EPP (Energy Performance Preference) to performance
for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
  if [ -f "$epp" ]; then
    echo performance > "$epp"
  fi
done
echo "- Energy Performance Preference: performance"

echo "System configured for MAXIMUM performance."
