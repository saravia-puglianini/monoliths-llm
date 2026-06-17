#!/bin/bash

# =============================================================================
# Jira Timer & Reminder Script (Persistent CSV Version + Extras)
# =============================================================================
# Formato CSV: YYYY-MM-DD;HHam/pm;Proyecto;Descripción
# =============================================================================

LOCKFILE="/tmp/jira_reminder.pid"
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" >/dev/null 2>&1; then exit 0; fi
fi
echo "$$" > "$LOCKFILE"

YAD_BIN="/usr/bin/yad"
DIR="/home/user/monoliths-llm"
BROWSER_BIN=$(command -v firefox || command -v google-chrome-stable || command -v google-chrome || command -v chromium || echo "xdg-open")
JUSTIFICAR_DIR="$HOME/.justificar"
JUSTIFICAR_CSV="$JUSTIFICAR_DIR/justificar.csv"
BACKUP_DIR="$JUSTIFICAR_DIR/backups"
mkdir -p "$BACKUP_DIR"
touch "$JUSTIFICAR_CSV"

if [ -z "$DISPLAY" ]; then export DISPLAY=":0"; fi
if [ -z "$XAUTHORITY" ]; then
    [ -f "/run/user/$(id -u)/gdm/Xauthority" ] && export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    [ -f "$HOME/.Xauthority" ] && export XAUTHORITY="$HOME/.Xauthority"
fi

HORAS_LABORALES=(9 10 11 12 14 15 16 17)

# Backup al iniciar el script si hay contenido
if [ -s "$JUSTIFICAR_CSV" ]; then
    cp "$JUSTIFICAR_CSV" "$BACKUP_DIR/justificar_$(date +%Y%m%d_%H%M%S).csv.bak"
    # Mantener solo los últimos 10 backups
    ls -t "$BACKUP_DIR"/*.bak | tail -n +11 | xargs -r rm
fi

get_last_entry() {
    if [ -s "$JUSTIFICAR_CSV" ]; then
        tail -n 1 "$JUSTIFICAR_CSV"
    else
        echo ";;Sin Proyecto;Sin Descripción"
    fi
}

format_hour_csv() {
    local h=$1
    if [ "$h" -lt 12 ]; then echo "${h}am"; elif [ "$h" -eq 12 ]; then echo "12pm"; else echo "$((h-12))pm"; fi
}

while true; do
    DayOfWeek=$(date +%u)
    TodayMMDD=$(date +%m-%d)
    if [ "$DayOfWeek" -gt 5 ] || grep -q "^$TodayMMDD$" "$HOME/.holidays" 2>/dev/null; then
        sleep 3600
        continue
    fi
    
    CURRENT_DATE=$(date +%Y-%m-%d)
    CURRENT_HOUR_STR=$(date +%H)
    CURRENT_HOUR=$((10#$CURRENT_HOUR_STR))

    if pgrep -af "yad --title Ops360" > /dev/null || pgrep -af "yad --title Jira" > /dev/null || pgrep -af "yad --title 'Log de Horas'" > /dev/null; then
        sleep 5; continue
    fi

    HORAS_ADEUDADAS=()
    for h in "${HORAS_LABORALES[@]}"; do
        if [ "$h" -le "$CURRENT_HOUR" ]; then
            H_STR=$(format_hour_csv "$h")
            if ! grep -q "^$CURRENT_DATE;$H_STR;" "$JUSTIFICAR_CSV"; then
                HORAS_ADEUDADAS+=("$h")
            fi
        fi
    done

    COUNT_ADEUDADAS=${#HORAS_ADEUDADAS[@]}
    if [ "$COUNT_ADEUDADAS" -eq 0 ]; then sleep 5; continue; fi

    # MODAL 1: ¿Justificó?
    MSG_BODY="Tienes un atraso de <b>$COUNT_ADEUDADAS hora(s)</b>.\n¿Justificó las horas en Jira?"
    $YAD_BIN --title "Jira - Control de Horas" \
        --window-icon "appointment-reminder" \
        --text "<b>Control de Tareas</b>\n\n$MSG_BODY" \
        --button="Ver Log:2" \
        --button="No:1" \
        --button="Si:0" \
        --center --width=420 --timeout=120 --always-on-top

    RESP=$?
    if [ $RESP -eq 2 ]; then
        "$DIR/ver-horas.sh" &
        sleep 5; continue
    elif [ $RESP -eq 1 ]; then
        $BROWSER_BIN "https://mipandero.atlassian.net/jira/for-you" &
        sleep 5; continue
    fi

    # FLUJO DE INGRESO
    while true; do
        HORAS_A_JUSTIFICAR=$($YAD_BIN --title "Jira - Cantidad" \
            --text "Debe <b>$COUNT_ADEUDADAS hora(s)</b>.\n¿Cuántas va a registrar ahora?" \
            --entry --entry-label="Horas:" --numeric --center --width=300 --always-on-top)
        
        [ $? -ne 0 ] || [ -z "$HORAS_A_JUSTIFICAR" ] && break 2
        HORAS_A_JUSTIFICAR=$(echo "$HORAS_A_JUSTIFICAR" | sed 's/[^0-9]*//g')
        [ -z "$HORAS_A_JUSTIFICAR" ] && continue

        # MODAL 3: Proyecto y Descripción
        LAST_ENTRY=$(get_last_entry)
        LAST_PROJ=$(echo "$LAST_ENTRY" | cut -d';' -f3)
        LAST_DESC=$(echo "$LAST_ENTRY" | cut -d';' -f4)

        DESC_DATA=$($YAD_BIN --form --title "Jira - Registro Detallado" \
            --text "Información para las $HORAS_A_JUSTIFICAR hora(s) justificadas:" \
            --field="Proyecto":ENTRY "$LAST_PROJ" \
            --field="Descripción":ENTRY "" \
            --button="Aceptar:0" \
            --button="Igual al anterior:2" \
            --button="Revisar Jira:3" \
            --center --width=500 --always-on-top)
        
        RET_D=$?
        if [ $RET_D -eq 3 ]; then $BROWSER_BIN "https://mipandero.atlassian.net/jira/for-you" & continue; fi

        FINAL_PROJ=""
        FINAL_DESC=""

        if [ $RET_D -eq 2 ]; then
            FINAL_PROJ="$LAST_PROJ"
            FINAL_DESC="$LAST_DESC"
        elif [ $RET_D -eq 0 ]; then
            FINAL_PROJ=$(echo "$DESC_DATA" | cut -d'|' -f1)
            FINAL_DESC=$(echo "$DESC_DATA" | cut -d'|' -f2)
        else
            break
        fi

        # Grabación
        PROCESADAS=0
        for h in "${HORAS_ADEUDADAS[@]}"; do
            if [ "$PROCESADAS" -lt "$HORAS_A_JUSTIFICAR" ]; then
                H_STR=$(format_hour_csv "$h")
                echo "$CURRENT_DATE;$H_STR;$FINAL_PROJ;$FINAL_DESC" >> "$JUSTIFICAR_CSV"
                PROCESADAS=$((PROCESADAS + 1))
            fi
        done

        $YAD_BIN --title "Jira - Éxito" --text "Registro completado y respaldado." \
            --button="OK:0" --center --width=300 --timeout=3 --always-on-top
        break
    done
    sleep 5
done
