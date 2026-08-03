#!/bin/dash
# Script de loopback optimizado con mezcla multitarea dmix y dsnoop ALSA
# Permite escuchar el micrófono filtrado en tiempo real Y usarlo en Google Chrome simultáneamente.

get_input_devices() {
    # Opción 1: Dispositivo dsnoop compartido (Recomendado para usar con Chrome a la vez)
    echo "plug:dsnoop_mic"
    echo "dsnoop Compartido (Permite Chrome + Monitoreo al mismo tiempo)"

    arecord -l | grep "^card" | while read -r line; do
        card_num=$(echo "$line" | cut -d: -f1 | awk '{print $2}')
        dev_num=$(echo "$line" | cut -d: -f2 | cut -d, -f2 | awk '{print $2}')
        name=$(echo "$line" | cut -d'[' -f2 | cut -d']' -f1)
        sub_name=$(echo "$line" | cut -d':' -f3 | sed 's/^[[:space:]]*//')
        
        echo "plughw:${card_num},${dev_num}"
        echo "Tarjeta $card_num: $name ($sub_name) [Exclusivo]"
    done
}

get_output_devices() {
    echo "plug:default"
    echo "Mezclador ALSA dmix (Permite Chrome + Monitoreo al mismo tiempo)"
}

start_gst() {
    INPUT_DEV="$1"
    OUTPUT_DEV="$2"

    gst-launch-1.0 -q \
        alsasrc device="$INPUT_DEV" buffer-time=1 latency-time=1 blocksize=32 ! \
        audioconvert ! \
        audioresample quality=0 ! \
        "audio/x-raw, rate=48000, channels=1" ! \
        audiochebband mode=band-pass lower-frequency=200 upper-frequency=3000 poles=2 ! \
        audiodynamic mode=expander threshold=0.008 ratio=2.0 characteristics=soft-knee ! \
        audioconvert ! \
        alsasink device="$OUTPUT_DEV" sync=false buffer-time=1 latency-time=1 blocksize=32 >/dev/null 2>&1 &
    
    echo $!
}

main() {
    TMPFILE_IN=$(mktemp)
    get_input_devices > "$TMPFILE_IN"

    if [ ! -s "$TMPFILE_IN" ]; then
        yad --error --title="Error" --text="No se encontraron micrófonos ALSA."
        rm -f "$TMPFILE_IN"
        exit 1
    fi

    # Por defecto usaremos dsnoop para compartir el mic JBL con Chrome simultáneamente
    SELECTED_IN="plug:dsnoop_mic"
    SELECTED_OUT="plug:default"

    rm -f "$TMPFILE_IN"

    # Bucle de control interactivo con Pausa / Reanudar
    PAUSED=0
    GST_PID=""

    while true; do
        if [ "$PAUSED" -eq 0 ]; then
            if [ -z "$GST_PID" ] || ! kill -0 "$GST_PID" 2>/dev/null; then
                GST_PID=$(start_gst "$SELECTED_IN" "$SELECTED_OUT")
            fi
            
            STATUS_TEXT="🎙️ <b>ESTADO: MONITOREO ACTIVO (dsnoop + dmix)</b>\n\n📥 <b>Entrada:</b> $SELECTED_IN (Compartido con Chrome via dsnoop)\n📤 <b>Salida:</b> $SELECTED_OUT (Compartida via dmix)\n\n✨ <i>Gracias a dsnoop puedes usar el micrófono en Google Chrome y escucharte al mismo tiempo.</i>"
            BTN_ACTION="Pausar Monitoreo:10"
        else
            if [ -n "$GST_PID" ]; then
                kill "$GST_PID" 2>/dev/null
                GST_PID=""
            fi
            
            STATUS_TEXT="⏸️ <b>ESTADO: PAUSADO</b>\n\n🟢 <b>El monitoreo de voz está pausado.</b>\n\n💡 <i>Puedes seguir usando el micrófono en Chrome o presionar 'Reanudar Monitoreo'.</i>"
            BTN_ACTION="Reanudar Monitoreo:10"
        fi

        yad --info \
            --title="Control de Loopback de Audio" \
            --text="$STATUS_TEXT" \
            --width=620 --height=230 \
            --button="$BTN_ACTION" \
            --button="Salir/Detener:0" 2>/dev/null

        EXIT_CODE=$?

        if [ "$EXIT_CODE" -eq 10 ]; then
            if [ "$PAUSED" -eq 0 ]; then
                PAUSED=1
            else
                PAUSED=0
            fi
        else
            [ -n "$GST_PID" ] && kill "$GST_PID" 2>/dev/null
            break
        fi
    done
}

main