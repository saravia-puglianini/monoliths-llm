#!/bin/bash

# =============================================================================
# Script: ops360-reminder.sh
# Descripción: Recordatorio de 4 toques para OPS Entelgy:
#              1. Inicio
#              2. Inicio Almuerzo
#              3. Fin Almuerzo
#              4. Fin
# =============================================================================

# Evitar que se ejecuten varias copias del propio script (Lockfile robusto)
LOCKFILE='/tmp/ops360_reminder.pid'
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" >/dev/null 2>&1; then
        # Ya hay uno corriendo realmente
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"

# Configuración de horarios
T2_START='12:55'
T3_START='14:00'
T4_START='17:55'

# Rutas absolutas para mayor compatibilidad
YAD_BIN='/usr/bin/yad'
BROWSER_BIN=$(command -v firefox || command -v google-chrome-stable || command -v google-chrome || command -v chromium || echo "xdg-open")

# Intentar detectar el DISPLAY y XAUTHORITY dinámicamente
if [ -z "$DISPLAY" ]; then
    export DISPLAY=':0'
fi

if [ -z "$XAUTHORITY" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

# Función para obtener el estado actual
get_status_summary() {
    local s1='[ ]' && [ -f "$FLAG_T1" ] && s1='[x]'
    local s2='[ ]' && [ -f "$FLAG_T2" ] && s2='[x]'
    local s3='[ ]' && [ -f "$FLAG_T3" ] && s3='[x]'
    local s4='[ ]' && [ -f "$FLAG_T4" ] && s4='[x]'
    
    echo "<b>Progreso HOY:</b>\n1. $s1 Entrada\n2. $s2 Inicio Almuerzo\n3. $s3 Fin Almuerzo\n4. $s4 Salida"
}

# Función para el diálogo
show_dialog() {
    local TIPO_TOKE="$1"
    local PROGRESS=$(get_status_summary)
    
    # Bloqueo estricto: Si ya hay CUALQUIER ventana de Ops360 abierta, no abrir otra
    if pgrep -af 'yad --title Ops360' > /dev/null; then
        return 1
    fi

    # Primera ventana
    $YAD_BIN --title "Ops360 - Recordatorio: $TIPO_TOKE" \
        --window-icon 'appointment-reminder' \
        --text "<b>Recordatorio:</b>\n\n<span color='blue' size='large'>→ $TIPO_TOKE ←</span>\n\n$PROGRESS\n\n<b>¿ya registro el ops entelgy?</b>" \
        --button='Si:0' \
        --button='No:1' \
        --center \
        --width=450 \
        --timeout=60 \
        --always-on-top \
        --fixed
    
    RESPONSE=$?

    if [ $RESPONSE -eq 1 ]; then
        $BROWSER_BIN 'https://ops360.entelgy.pe' &
        return 1
    elif [ $RESPONSE -eq 0 ]; then
        # Segunda ventana (Confirmación)
        # Usamos el mismo prefijo en el título para que pgrep lo detecte si algo intenta abrirse
        $YAD_BIN --title 'Ops360 - Verificación de Toke' \
            --window-icon 'help-question' \
            --text "<b>¿Confirmación final?</b>\n\n¿Ha verificado que su registro de <b>$TIPO_TOKE</b> quedó guardado correctamente?" \
            --button='Si:0' \
            --button='No:1' \
            --center \
            --width=350 \
            --timeout=60 \
            --always-on-top \
            --fixed
        
        if [ $? -eq 0 ]; then
            return 0
        else
            $BROWSER_BIN 'https://ops360.entelgy.pe' &
            return 1
        fi
    fi
    return 2
}

# Bucle principal para ejecución continua (daemons)
while true; do
    # Skip weekends
    DayOfWeek=$(date +%u)
    TodayMMDD=$(date +%m-%d)
    if [ "$DayOfWeek" -gt 5 ] || grep -q "^$TodayMMDD$" "$HOME/.holidays" 2>/dev/null; then
        sleep 3600
        continue
    fi
    
    # Evitar que se lancen nuevas preguntas si ya hay una ventana activa de Ops360
    if pgrep -af 'yad --title Ops360' > /dev/null; then
        sleep 2
        continue
    fi

    CURRENT_TIME=$(date +%H:%M)
    TODAY=$(date +%Y-%m-%d)
    
    FLAG_T1="/tmp/ops360_t1_$TODAY"
    FLAG_T2="/tmp/ops360_t2_$TODAY"
    FLAG_T3="/tmp/ops360_t3_$TODAY"
    FLAG_T4="/tmp/ops360_t4_$TODAY"

    if [[ "$CURRENT_TIME" > '08:55' ]] && [[ "$CURRENT_TIME" < '19:00' ]]; then
        # 1. Entrada
        if [ ! -f "$FLAG_T1" ]; then
            show_dialog 'Entrada' && touch "$FLAG_T1"
        
        # 2. Inicio Almuerzo
        elif [[ "$CURRENT_TIME" > "$T2_START" ]] && [ ! -f "$FLAG_T2" ]; then
            show_dialog 'Inicio Almuerzo' && touch "$FLAG_T2"
            
        # 3. Fin Almuerzo
        elif [[ "$CURRENT_TIME" > "$T3_START" ]] && [ ! -f "$FLAG_T3" ]; then
            show_dialog 'Fin Almuerzo' && touch "$FLAG_T3"
            
        # 4. Salida
        elif [[ "$CURRENT_TIME" > "$T4_START" ]] && [ ! -f "$FLAG_T4" ]; then
            show_dialog 'Salida' && touch "$FLAG_T4"
        fi
    fi

    sleep 5
done
rm -f "$LOCKFILE"


