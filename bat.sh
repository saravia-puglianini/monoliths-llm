#!/bin/bash

# Rutas de la batería y la corriente en tu sistema
ADP_PATH="/sys/class/power_supply/ADP1"
BAT_PATH="/sys/class/power_supply/BAT0"

# Si BAT0 no existe, buscar cualquier batería BAT*
if [ ! -d "$BAT_PATH" ]; then
    BAT_PATH=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
fi

# Si ADP1 no existe, buscar cualquier ADP* o AC*
if [ ! -d "$ADP_PATH" ]; then
    ADP_PATH=$(ls -d /sys/class/power_supply/AC* /sys/class/power_supply/ADP* 2>/dev/null | head -n 1)
fi

# Verificar si la corriente está conectada
if [ -n "$ADP_PATH" ] && [ -f "$ADP_PATH/online" ]; then
    online=$(cat "$ADP_PATH/online")
else
    online=0
fi

# Obtener la capacidad y estado de la batería
if [ -n "$BAT_PATH" ] && [ -f "$BAT_PATH/capacity" ]; then
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

if [ -n "$BAT_PATH" ] && [ -d "$BAT_PATH" ]; then
    charge=""
    charge_full=""
    current=""

    if [ -f "$BAT_PATH/charge_now" ] && [ -f "$BAT_PATH/current_now" ]; then
        charge=$(cat "$BAT_PATH/charge_now")
        charge_full=$(cat "$BAT_PATH/charge_full" 2>/dev/null)
        current=$(cat "$BAT_PATH/current_now")
    elif [ -f "$BAT_PATH/energy_now" ] && [ -f "$BAT_PATH/power_now" ]; then
        charge=$(cat "$BAT_PATH/energy_now")
        charge_full=$(cat "$BAT_PATH/energy_full" 2>/dev/null)
        current=$(cat "$BAT_PATH/power_now")
    fi

    precise_calculated=0
    if [ "$status" = "Discharging" ] && [ -f /tmp/bat.sh.log ]; then
        read -r start_time start_capacity < /tmp/bat.sh.log
        current_time=$(date +%s)
        if [ -n "$start_time" ] && [ -n "$start_capacity" ] && [ -n "$capacity" ] && [ "$capacity" != "N/A" ]; then
            elapsed_seconds=$(( current_time - start_time ))
            consumed_capacity=$(( start_capacity - capacity ))
            if [ "$elapsed_seconds" -gt 0 ] && [ "$consumed_capacity" -gt 0 ]; then
                remaining_seconds=$(( capacity * elapsed_seconds / consumed_capacity ))
                hours=$(( remaining_seconds / 3600 ))
                mins=$(( (remaining_seconds % 3600) / 60 ))

                h_str=""
                m_str=""
                if [ $hours -gt 0 ]; then
                    [ $hours -eq 1 ] && h_str="1 hora" || h_str="$hours horas"
                fi
                if [ $mins -gt 0 ]; then
                    [ $mins -eq 1 ] && m_str="1 minuto" || m_str="$mins minutos"
                fi

                if [ -n "$h_str" ] && [ -n "$m_str" ]; then
                    echo "Te quedan $h_str y $m_str de batería (estimación precisa) ⏳"
                elif [ -n "$h_str" ]; then
                    echo "Te quedan $h_str de batería (estimación precisa) ⏳"
                elif [ -n "$m_str" ]; then
                    echo "Te quedan $m_str de batería (estimación precisa) ⏳"
                else
                    echo "Te queda menos de 1 minuto de batería (estimación precisa) ⏳"
                fi
                precise_calculated=1
            fi
        fi
    fi

    if [ "$precise_calculated" -eq 0 ] && [ -n "$charge" ] && [ -n "$current" ] && [ "$current" -gt 0 ]; then
        if [ "$status" = "Discharging" ]; then
            hours=$(( charge / current ))
            mins=$(( (charge % current) * 60 / current ))
            
            h_str=""
            m_str=""
            if [ $hours -gt 0 ]; then
                [ $hours -eq 1 ] && h_str="1 hora" || h_str="$hours horas"
            fi
            if [ $mins -gt 0 ]; then
                [ $mins -eq 1 ] && m_str="1 minuto" || m_str="$mins minutos"
            fi

            if [ -n "$h_str" ] && [ -n "$m_str" ]; then
                echo "Te quedan $h_str y $m_str de batería ⏳"
            elif [ -n "$h_str" ]; then
                echo "Te quedan $h_str de batería ⏳"
            elif [ -n "$m_str" ]; then
                echo "Te quedan $m_str de batería ⏳"
            else
                echo "Te queda menos de 1 minuto de batería ⏳"
            fi
        elif [ "$status" = "Charging" ] && [ -n "$charge_full" ] && [ "$charge_full" -gt "$charge" ]; then
            needed=$(( charge_full - charge ))
            hours=$(( needed / current ))
            mins=$(( (needed % current) * 60 / current ))

            h_str=""
            m_str=""
            if [ $hours -gt 0 ]; then
                [ $hours -eq 1 ] && h_str="1 hora" || h_str="$hours horas"
            fi
            if [ $mins -gt 0 ]; then
                [ $mins -eq 1 ] && m_str="1 minuto" || m_str="$mins minutos"
            fi

            if [ -n "$h_str" ] && [ -n "$m_str" ]; then
                echo "Tiempo para carga completa: $h_str y $m_str ⚡"
            elif [ -n "$h_str" ]; then
                echo "Tiempo para carga completa: $h_str ⚡"
            elif [ -n "$m_str" ]; then
                echo "Tiempo para carga completa: $m_str ⚡"
            else
                echo "Falta menos de 1 minuto para carga completa ⚡"
            fi
        fi
    fi
fi
