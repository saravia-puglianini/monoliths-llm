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
JIRA_CONFIG="$JUSTIFICAR_DIR/jira_config"

# Backup al iniciar el script si hay contenido
if [ -s "$JUSTIFICAR_CSV" ]; then
    cp "$JUSTIFICAR_CSV" "$BACKUP_DIR/justificar_$(date +%Y%m%d_%H%M%S).csv.bak"
    # Mantener solo los últimos 10 backups
    ls -t "$BACKUP_DIR"/*.bak | tail -n +11 | xargs -r rm
fi

check_jira_config() {
    if [ ! -f "$JIRA_CONFIG" ]; then
        $YAD_BIN --title "Configuración de Jira" \
            --text "No se encontró el archivo de configuración en <b>$JIRA_CONFIG</b>.\n\n¿Desea crearlo ahora?" \
            --button="No:1" --button="Sí:0" --center --width=400 --always-on-top
        if [ $? -eq 0 ]; then
            DATA=$($YAD_BIN --form --title "Configurar Jira" \
                --text "Ingrese sus credenciales de Jira:" \
                --field="Email/Usuario":ENTRY "" \
                --field="API Token":HENTRY "" \
                --field="Dominio (URL)":ENTRY "https://mipandero.atlassian.net" \
                --center --width=450 --always-on-top)
            if [ $? -eq 0 ]; then
                EMAIL=$(echo "$DATA" | cut -d'|' -f1)
                TOKEN=$(echo "$DATA" | cut -d'|' -f2)
                DOMAIN=$(echo "$DATA" | cut -d'|' -f3)
                if [ -n "$EMAIL" ] && [ -n "$TOKEN" ] && [ -n "$DOMAIN" ]; then
                    echo "JIRA_EMAIL=\"$EMAIL\"" > "$JIRA_CONFIG"
                    echo "JIRA_API_TOKEN=\"$TOKEN\"" >> "$JIRA_CONFIG"
                    echo "JIRA_DOMAIN=\"$DOMAIN\"" >> "$JIRA_CONFIG"
                    chmod 600 "$JIRA_CONFIG"
                    $YAD_BIN --title "Configuración" --text "Configuración guardada correctamente." --button="OK:0" --center --width=300 --always-on-top
                else
                    $YAD_BIN --title "Error" --text "Los campos no pueden estar vacíos." --button="OK:0" --center --always-on-top
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi
    return 0
}

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
    # Check if reminders are paused
    PAUSE_FILE="$HOME/.pause_until"
    if [ -f "$PAUSE_FILE" ]; then
        PAUSE_UNTIL=$(cat "$PAUSE_FILE")
        if [ -n "$PAUSE_UNTIL" ]; then
            CURRENT_TS=$(date +%s)
            TARGET_TS=$(date -d "$PAUSE_UNTIL" +%s 2>/dev/null)
            if [ $? -eq 0 ] && [ "$CURRENT_TS" -lt "$TARGET_TS" ]; then
                sleep 300
                continue
            fi
        fi
    fi

    DayOfWeek=$(date +%u)
    TodayMMDD=$(date +%m-%d)
    if [ "$DayOfWeek" -gt 5 ] || grep -q "^$TodayMMDD$" "$HOME/.holidays" 2>/dev/null; then
        sleep 3600
        continue
    fi
    
    CURRENT_DATE=$(date +%Y-%m-%d)
    CURRENT_HOUR_STR=$(date +%H)
    CURRENT_HOUR=$((10#$CURRENT_HOUR_STR))

    if [ "$CURRENT_HOUR" -lt 9 ] || [ "$CURRENT_HOUR" -ge 18 ]; then
        sleep 300
        continue
    fi

    if pgrep -af "yad --title Ops360" > /dev/null || pgrep -af "yad --title Jira" > /dev/null || pgrep -af "yad --title 'Log de Horas'" > /dev/null; then
        sleep 5; continue
    fi

    # Sincronizar worklogs de Jira a CSV local para soportar múltiples dispositivos
    if [ -f "$JIRA_CONFIG" ]; then
        python3 "$DIR/jira_helper.py" sync "$CURRENT_DATE" >/dev/null 2>&1
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
        --button="Hoy es Feriado:3" \
        --button="Ver Log:2" \
        --button="No:1" \
        --button="Si:0" \
        --center --width=420 --timeout=120 --always-on-top

    RESP=$?
    if [ $RESP -eq 3 ]; then
        $YAD_BIN --title "Confirmar Feriado" \
            --text "¿Está seguro de que hoy es feriado?" \
            --button="No:1" --button="Sí:0" \
            --center --width=350 --always-on-top
        if [ $? -eq 0 ]; then
            echo "$TodayMMDD" >> "$HOME/.holidays"
            sleep 3600
            continue
        else
            sleep 5; continue
        fi
    elif [ $RESP -eq 2 ]; then
        "$DIR/ver-horas.sh" &
        sleep 5; continue
    elif [ $RESP -eq 1 ]; then
        $BROWSER_BIN "https://mipandero.atlassian.net/jira/for-you" &
        sleep 5; continue
    fi

    # Asegurar configuración de Jira
    check_jira_config
    # Si decide no configurar/cancela, igual permitimos registrar de forma manual

    # FLUJO DE INGRESO
    while true; do
        HORAS_A_JUSTIFICAR=$($YAD_BIN --title "Jira - Cantidad" \
            --text "Debe <b>$COUNT_ADEUDADAS hora(s)</b>.\n¿Cuántas va a registrar ahora?" \
            --entry --entry-label="Horas:" --numeric --center --width=300 --always-on-top)
        
        [ $? -ne 0 ] || [ -z "$HORAS_A_JUSTIFICAR" ] && break 2
        HORAS_A_JUSTIFICAR=$(echo "$HORAS_A_JUSTIFICAR" | sed 's/[^0-9]*//g')
        [ -z "$HORAS_A_JUSTIFICAR" ] && continue

        # Intentar obtener tareas de Jira para selección
        HAS_JIRA=0
        if [ -f "$JIRA_CONFIG" ]; then
            HAS_JIRA=1
        fi

        WAS_FINISHED=0
        LAST_ENTRY=$(get_last_entry)
        LAST_PROJ=$(echo "$LAST_ENTRY" | cut -d';' -f3)

        if [ "$HAS_JIRA" -eq 1 ]; then
            if [[ "$LAST_PROJ" =~ ^[A-Za-z0-9]+-[0-9]+$ ]]; then
                $YAD_BIN --title "Jira - Tarea Anterior" \
                    --text "¿Está seguro que terminó la tarea: <b>$LAST_PROJ</b>?" \
                    --button="Aún no he terminado:1" --button="Confirmar:0" --center --width=400 --always-on-top
                if [ $? -eq 0 ]; then
                    # Transition previous task to Done/Hecho!
                    python3 "$DIR/jira_helper.py" transition "$LAST_PROJ" hecho >/dev/null 2>&1
                    WAS_FINISHED=1
                fi
            fi
        fi

        FINAL_PROJ=""
        FINAL_DESC=""
        FINAL_PARENT=""
        LOG_TO_JIRA=0

        if [ "$HAS_JIRA" -eq 1 ]; then
            # Obtener lista de tareas desde la API
            TASKS_LIST=$(python3 "$DIR/jira_helper.py" get-issues 2>/dev/null)
            if [ -n "$TASKS_LIST" ]; then
                # Construir parámetros para YAD list
                YAD_ARGS=()
                while IFS='|' read -r k p_name pk_parent p_sum_parent s; do
                    if [ -n "$k" ]; then
                        YAD_ARGS+=("$k" "$p_name" "$pk_parent" "$p_sum_parent" "$s")
                    fi
                done <<< "MANUAL|MANUAL|N/A|N/A|Tipear
$TASKS_LIST"
                
                SELECT_DATA=$($YAD_BIN --list --title "Jira - Seleccionar Tarea" \
                    --text "Seleccione la tarea para registrar las $HORAS_A_JUSTIFICAR hora(s):" \
                    --column="Clave (Task Key)" \
                    --column="Project Name" \
                    --column="Buscar" \
                    --column="Historia Parent title" \
                    --column="Tarea title" \
                    --hide-column=1 \
                    --fullscreen --center --always-on-top "${YAD_ARGS[@]}")
                
                if [ $? -ne 0 ] || [ -z "$SELECT_DATA" ]; then
                    continue
                fi
                
                TICKET_KEY=$(echo "$SELECT_DATA" | cut -d'|' -f1)
                PARENT_KEY=$(echo "$SELECT_DATA" | cut -d'|' -f3 | cut -d' ' -f1)
                TASK_TITLE=$(echo "$SELECT_DATA" | cut -d'|' -f5)
                TASK_TITLE="${TASK_TITLE% (*)}"
                if [ "$TICKET_KEY" != "MANUAL" ]; then
                    FINAL_PROJ="$TICKET_KEY"
                    FINAL_PARENT="$PARENT_KEY"
                    LOG_TO_JIRA=1
                fi
            else
                # Alerta cuando no hay historias asignadas
                $YAD_BIN --title "Jira - Sin Historias" \
                    --image="dialog-warning" \
                    --text "<b>Atención:</b> No tienes Historias asignadas en Jira.\nEs imperativo que un LT te asigne Historias." \
                    --button="Registrar Manualmente:0" --center --width=450 --always-on-top
            fi
        fi

        if [ "$LOG_TO_JIRA" -eq 1 ]; then
            DESC_DATA=$($YAD_BIN --form --title "Jira - Descripción del Trabajo" \
                --text "Ingrese el detalle de trabajo para la tarea $FINAL_PROJ:" \
                --field="Descripción":ENTRY "$TASK_TITLE" \
                --center --width=500 --always-on-top)
            
            if [ $? -ne 0 ] || [ -z "$DESC_DATA" ]; then
                continue
            fi
            FINAL_DESC=$(echo "$DESC_DATA" | cut -d'|' -f1)
        else
            # MODAL 3: Proyecto y Descripción Manual
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

            if [ $RET_D -eq 2 ]; then
                FINAL_PROJ="$LAST_PROJ"
                FINAL_DESC="$LAST_DESC"
            elif [ $RET_D -eq 0 ]; then
                FINAL_PROJ=$(echo "$DESC_DATA" | cut -d'|' -f1)
                FINAL_DESC=$(echo "$DESC_DATA" | cut -d'|' -f2)
            else
                break
            fi
        fi

        # Transiciones de estado automáticas en Jira
        if [ "$HAS_JIRA" -eq 1 ]; then
            if [[ "$FINAL_PROJ" =~ ^[A-Za-z0-9]+-[0-9]+$ ]]; then
                # Transicionar nueva tarea a "En progreso"
                python3 "$DIR/jira_helper.py" transition "$FINAL_PROJ" in_progress >/dev/null 2>&1
                
                # Transicionar la historia padre (parent) a "En progreso" si existe
                if [ -n "$FINAL_PARENT" ] && [ "$FINAL_PARENT" != "N/A" ]; then
                    python3 "$DIR/jira_helper.py" transition "$FINAL_PARENT" in_progress >/dev/null 2>&1
                fi
                
                # Si es diferente de la anterior y la anterior no terminó, transicionarla a "Detenido"
                if [ "$WAS_FINISHED" -eq 0 ] && [ "$FINAL_PROJ" != "$LAST_PROJ" ] && [[ "$LAST_PROJ" =~ ^[A-Za-z0-9]+-[0-9]+$ ]]; then
                    python3 "$DIR/jira_helper.py" transition "$LAST_PROJ" detenido >/dev/null 2>&1
                    
                    # También transicionar el padre anterior a "Detenido" si el padre cambió
                    LAST_PARENT=$(python3 "$DIR/jira_helper.py" get-parent "$LAST_PROJ" 2>/dev/null)
                    if [ -n "$LAST_PARENT" ] && [ "$LAST_PARENT" != "N/A" ] && [ "$LAST_PARENT" != "$FINAL_PARENT" ]; then
                        python3 "$DIR/jira_helper.py" transition "$LAST_PARENT" detenido >/dev/null 2>&1
                    fi
                fi
            fi
        fi

        # Grabación real en Jira
        WORKLOG_URL=""
        if [ "$LOG_TO_JIRA" -eq 1 ]; then
            WORKLOG_URL=$(python3 "$DIR/jira_helper.py" log-work "$FINAL_PROJ" "$HORAS_A_JUSTIFICAR" "$FINAL_DESC" 2>/dev/null)
            if [[ ! "$WORKLOG_URL" =~ ^https?:// ]]; then
                WORKLOG_URL=""
            fi
        fi

        # Grabación local
        PROCESADAS=0
        for h in "${HORAS_ADEUDADAS[@]}"; do
            if [ "$PROCESADAS" -lt "$HORAS_A_JUSTIFICAR" ]; then
                H_STR=$(format_hour_csv "$h")
                echo "$CURRENT_DATE;$H_STR;$FINAL_PROJ;$FINAL_DESC;$WORKLOG_URL" >> "$JUSTIFICAR_CSV"
                PROCESADAS=$((PROCESADAS + 1))
            fi
        done

        $YAD_BIN --title "Jira - Éxito" --text "Registro completado y respaldado." \
            --button="OK:0" --center --width=300 --timeout=3 --always-on-top

        # Verificar si se completó el registro de las 8 horas de hoy
        TODAY_COUNT=$(grep -c "^$CURRENT_DATE;" "$JUSTIFICAR_CSV")
        if [ "$TODAY_COUNT" -eq 8 ]; then
            $YAD_BIN --title "Jira - Reporte Diario" \
                --text "¡Has registrado las 8 horas de hoy!\n¿Deseas abrir todos los enlaces en Chrome?" \
                --button="No:1" --button="Sí, abrir:0" --center --always-on-top
            if [ $? -eq 0 ]; then
                python3 "$DIR/jira_helper.py" open-report "$CURRENT_DATE" &
            fi
        fi
        break
    done
    sleep 5
done
