#!/bin/bash
# Ejecutar hibernación real (S4) a nivel de hardware (ahorro del 100% de energía / 0W)
echo "Hibernando el equipo (guardando estado en disco)..."
doas sh -c "echo disk > /sys/power/state"
