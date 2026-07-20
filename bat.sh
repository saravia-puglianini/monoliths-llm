#!/bin/bash

# Rutas de la batería y la corriente en tu sistema
ADP_PATH="/sys/class/power_supply/ADP1"
BAT_PATH="/sys/class/power_supply/BAT0"

# Verificar si la corriente está conectada
if [ -f "$ADP_PATH/online" ]; then
    online=$(cat "$ADP_PATH/online")
else
    online=0
fi

# Obtener la capacidad y estado de la batería
if [ -f "$BAT_PATH/capacity" ]; then
    capacity=$(cat "$BAT_PATH/capacity")
    status=$(cat "$BAT_PATH/status")
else
    capacity="N/A"
    status="Desconocido"
fi

# Imprimir los resultados con iconos descriptivos
if [ "$online" -eq 1 ]; then
    echo "Corriente: Conectada 🔌"
else
    echo "Corriente: Desconectada 🔋"
fi

echo "Carga actual: ${capacity}% (${status})"
