#!/usr/bin/env bash

FILE="$HOME/monoliths-llm/script-literatura-core.sh"

set_version() {

    echo
    echo "=================================="
    echo "CAMBIANDO A => $1"
    echo "=================================="
    echo

    echo "ANTES:"
    grep VERSION "$FILE"
    echo

    # comentar todos
    sed -i \
        -e "s/^[[:space:]]*#\?VERSION='de_DE-thorsten-high.onnx'/    #VERSION='de_DE-thorsten-high.onnx'/" \
        -e "s/^[[:space:]]*#\?VERSION='en_US-ryan-high.onnx'/    #VERSION='en_US-ryan-high.onnx'/" \
        -e "s/^[[:space:]]*#\?VERSION='es_MX-claude-high.onnx'/    #VERSION='es_MX-claude-high.onnx'/" \
        "$FILE"

    echo "DESPUÉS DE COMENTAR:"
    grep VERSION "$FILE"
    echo

    # descomentar seleccionado
    sed -i \
        -e "s/^[[:space:]]*#VERSION='$1'/    VERSION='$1'/" \
        "$FILE"

    echo "DESPUÉS DE DESCOMENTAR:"
    grep VERSION "$FILE"
    echo
}

# Monitor de servicio python
(
    while sleep 2; do
        if ! pgrep -f "python_book_reader_service.py" > /dev/null; then
            echo "Python service not found. Escaping..."
            pkill -P $$ yad 2>/dev/null
            kill $$ 2>/dev/null
            exit
        fi
    done
) &
WATCHER_PID=$!
trap "kill $WATCHER_PID 2>/dev/null" EXIT

while true; do

    OPTION=$(yad \
        --width=300 \
        --height=260 \
        --center \
        --title="Choose Language" \
        --list \
        --column="Language" \
        "Listen German" \
        "Listen English" \
        "Listen Spanish" \
        "Stop" \
        "Saltar a linea")

    EXIT_CODE=$?

    [ $EXIT_CODE -ne 0 ] && break

    # quitar | extra que devuelve yad
    OPTION=$(echo "$OPTION" | cut -d'|' -f1)

    echo
    echo "OPTION => [$OPTION]"
    echo
    case "$OPTION" in

        "Listen German")
            set_version "de_DE-thorsten-high.onnx"
            ;;

        "Listen English")
            set_version "en_US-ryan-high.onnx"
            ;;

        "Listen Spanish")
            set_version "es_MX-claude-high.onnx"
            ;;

        "Stop")
            echo "Creating /tmp/STOP"
            touch /tmp/STOP
            ;;

        "Saltar a linea")
            CURRENT_FILE=$(cat /tmp/current_reading.txt 2>/dev/null)
            if [ -f "$CURRENT_FILE" ]; then
                NEW_POS=$(yad --entry --title="Saltar a linea" --text="Ingresa el número de fragmento (línea):" --entry-text="1")
                if [ $? -eq 0 ] && [ -n "$NEW_POS" ]; then
                    # Guardamos el número en el archivo .pos
                    # Al darle a "Listen" de nuevo, el script leerá este valor
                    echo "$NEW_POS" > "${CURRENT_FILE}.pos"
                    echo "Saltando a $NEW_POS en $CURRENT_FILE. Deteniendo..."
                    touch /tmp/STOP
                fi
            else
                yad --error --text="No se detectó ninguna lectura activa para saltar."
            fi
            ;;

        *)
            echo "NO MATCH"
            echo "VALOR => [$OPTION]"
            ;;
    esac

done