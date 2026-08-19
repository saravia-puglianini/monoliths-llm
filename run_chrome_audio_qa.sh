#!/bin/bash
# ==============================================================================
# Lanzador de Menú y Pruebas QA para Audio y Speech Recognition en Chrome Stable
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SERVICE="$SCRIPT_DIR/audio_chrome_qa_service.py"
REPORT_JSON="/tmp/qa_chrome_speech_report.json"

chmod +x "$PYTHON_SERVICE"

# Verificar si yad está disponible para modo visual
if command -v yad >/dev/null 2>&1; then
    while true; do
        SELECTION=$(yad --list \
            --title="QA Chrome Audio & Speech Recognition" \
            --image="audio-input-microphone" \
            --text="<b>Suite de Validación de Selección de Micrófono ALSA en Chrome Stable:</b>\nValida nivel de entrada (RMS) y Web Speech API en cada perfil." \
            --column="ID" --column="Nombre / Dispositivo ALSA" \
            --width=780 --height=390 \
            --center \
            "all" "▶ Ejecutar TODOS los 8 perfiles (688 al 695)" \
            "688" "688 | SOF Directo [microfono_laptop]" \
            "689" "689 | SOF Filtrado [microfono_laptop]" \
            "690" "690 | JBL Wireless Directo [entrada_buena_jbl]" \
            "691" "691 | JBL Wireless Filtrado [entrada_buena_jbl]" \
            "692" "692 | JBL Loopback JBL [entrada_buena_jbl]" \
            "693" "693 | JBL Filtrado + Loopback JBL [entrada_buena_jbl]" \
            "694" "694 | JBL Loopback SOF (Mic Laptop ➔ JBL) [entrada_buena_jbl]" \
            "695" "695 | JBL Filtrado Loopback SOF (Mic Laptop ➔ JBL) [entrada_buena_jbl]" \
            "view" "📊 Ver Último Reporte JSON Generado" \
            --button="Salir:1" --button="Iniciar Prueba:0" 2>/dev/null)

        ret=$?
        [ $ret -ne 0 ] && break

        CHOICE=$(echo "$SELECTION" | cut -d'|' -f1)

        if [ "$CHOICE" = "view" ]; then
            if [ -f "$REPORT_JSON" ]; then
                yad --text-info --title="Reporte QA JSON" --width=700 --height=450 --filename="$REPORT_JSON" --editable=false 2>/dev/null
            else
                yad --warning --text="Aún no se ha generado ningún reporte. Ejecuta una prueba primero." 2>/dev/null
            fi
        elif [ -n "$CHOICE" ]; then
            python3 "$PYTHON_SERVICE" --profile "$CHOICE" --timeout 15
        fi
    done
else
    # Modo terminal
    echo "Iniciando validador en modo CLI..."
    python3 "$PYTHON_SERVICE" "$@"
fi
