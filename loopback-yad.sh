#!/bin/dash
# Script de loopback con diagnóstico y control de volumen (Corregido)

LATENCY_MS=5

get_input_devices() {
    pactl list short sources | while read -r line; do
        name=$(echo "$line" | awk '{print $2}')
        # Ignorar los monitores (salidas de audio)
        if ! echo "$name" | grep -q "\.monitor"; then
            desc=$(pactl list sources | grep -A 20 "Name: $name" | grep "Description:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
            [ -z "$desc" ] && desc="$name"
            echo "$name"
            echo "$desc"
        fi
    done
}

get_default_sink() {
    # Usar awk '$NF' para capturar estrictamente la última palabra y evitar espacios en blanco
    SINK=$(pactl info | grep -E "Destino por defecto:|Default Sink:" | awk '{print $NF}')
    [ -z "$SINK" ] && SINK="alsa_output.usb-JBL_JBL_Quantum350_Wireless-00.analog-stereo"
    echo "$SINK"
}

create_loopback() {
    INPUT_DEVICE="$1"
    OUTPUT_SINK="$2"
    
    # 1. Asegurar que el micrófono origen esté al 100% y sin mutear
    pactl set-source-mute "$INPUT_DEVICE" 0 2>/dev/null
    pactl set-source-volume "$INPUT_DEVICE" 100% 2>/dev/null
    
    # 2. Cargar el módulo loopback
    MODULE_ID=$(pactl load-module module-loopback \
        source="$INPUT_DEVICE" \
        sink="$OUTPUT_SINK" \
        latency_msec="$LATENCY_MS" \
        rate=48000 \
        channels=2 2>&1)
    
    # Comprobar si devolvió un ID numérico válido
    if echo "$MODULE_ID" | grep -q "^[0-9]\+$"; then
        echo "$MODULE_ID"
    else
        echo "0"
    fi
}

main() {
    DEFAULT_SINK=$(get_default_sink)
    
    TMPFILE=$(mktemp)
    get_input_devices > "$TMPFILE"
    
    if [ ! -s "$TMPFILE" ]; then
        yad --error --title="Error" --text="No se encontraron dispositivos de entrada."
        rm -f "$TMPFILE"
        exit 1
    fi
    
    set --
    while IFS= read -r name && IFS= read -r desc; do
        set -- "$@" "$name" "$desc"
    done < "$TMPFILE"
    
    SELECTED=$(yad --list \
        --title="Loopback de Audio" \
        --text="Selecciona el micrófono/entrada:\n\n🎧 Destino: <b>$DEFAULT_SINK</b>" \
        --column="ID (Nombre técnico)" --column="Descripción del Dispositivo" \
        --width=850 --height=400 \
        --print-column=1 \
        "$@" \
        --button="Cancelar:1" --button="Iniciar Loopback:0" 2>/dev/null)
    
    rm -f "$TMPFILE"
    
    if [ $? -eq 0 ] && [ -n "$SELECTED" ]; then
        # Limpiar el string seleccionado (por si yad devuelve separadores)
        SELECTED=$(echo "$SELECTED" | cut -d'|' -f1)
        
        # Iniciar el loopback usando PulseAudio/PipeWire-Pulse
        MODULE_ID=$(create_loopback "$SELECTED" "$DEFAULT_SINK")
        
        if [ "$MODULE_ID" != "0" ]; then
            # Abrir pavucontrol en segundo plano
            if command -v pavucontrol >/dev/null 2>&1; then
                pavucontrol &
                PAVU_PID=$!
            fi
            
            yad --info \
                --title="Loopback Activo" \
                --text="✅ <b>Loopback en ejecución</b>\n\n📥 <b>Entrada:</b> $SELECTED\n📤 <b>Salida:</b> $DEFAULT_SINK\n⚡ <b>Latencia:</b> ${LATENCY_MS}ms\n\n💡 <b>ATENCIÓN:</b>\nVe a <i>pavucontrol</i>, pestaña <b>'Reproducción' (Playback)</b> y asegúrate de que el 'Loopback' no esté silenciado y tenga volumen." \
                --width=600 --height=250 \
                --button="Detener Loopback:0" \
                --no-wrap 2>/dev/null
            
            # Limpiar al cerrar el diálogo
            pactl unload-module "$MODULE_ID" 2>/dev/null
            
            [ -n "$PAVU_PID" ] && kill "$PAVU_PID" 2>/dev/null
            
            yad --info --title="Loopback Detenido" \
                --text="✓ Loopback detenido correctamente." \
                --width=300 --height=50 \
                --button="OK:0" 2>/dev/null
        else
            yad --error --title="Error fatal" \
                --text="No se pudo crear el loopback. Revisa por terminal ejecutando:\npactl load-module module-loopback source=$SELECTED sink=$DEFAULT_SINK" \
                --width=500 --height=100
        fi
    fi
}

main