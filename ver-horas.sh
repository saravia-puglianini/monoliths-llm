#!/bin/bash

# =============================================================================
# Visualizador de Log de Horas
# =============================================================================

JUSTIFICAR_CSV="$HOME/.justificar/justificar.csv"
YAD_BIN="/usr/bin/yad"
export DISPLAY=:0
if [ -z "$XAUTHORITY" ]; then
    [ -f "/run/user/$(id -u)/gdm/Xauthority" ] && export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    [ -f "$HOME/.Xauthority" ] && export XAUTHORITY="$HOME/.Xauthority"
fi

DIR="/home/user/monoliths-llm"

if [ ! -f "$JUSTIFICAR_CSV" ]; then
    $YAD_BIN --title "Error" --text "No se encontró el archivo de log." --button="OK:0" --center
    exit 1
fi

# Preparar los datos para YAD (calculando el nombre del día dinámicamente)
# Mostramos las últimas 50 entradas con columna 'Día' y Enlace
tail -n 50 "$JUSTIFICAR_CSV" | tac | while IFS=';' read -r fecha hora proyecto descripcion link; do
    if [ -n "$fecha" ]; then
        dia=$(date -d "$fecha" +%A 2>/dev/null | sed 's/.*/\u&/')
        if [ -z "$link" ]; then
            link="N/A"
        fi
        printf "%s\n%s\n%s\n%s\n%s\n%s\n" "$fecha" "$dia" "$hora" "$proyecto" "$descripcion" "$link"
    fi
done | $YAD_BIN --list --title "Log de Horas - Últimos registros" \
    --column="Fecha" --column="Día" --column="Hora" --column="Proyecto" --column="Descripción" --column="Enlace" \
    --width=950 --height=400 --center --button="Generar Reporte:2" --button="Cerrar:0" \
    --window-icon "document-open"

RESP=$?
if [ $RESP -eq 2 ]; then
    python3 "$DIR/jira_helper.py" open-report
fi

