#!/bin/dash
# Archivo: tts_german.sh

# Texto de entrada
TEXT="$1"

# Función para convertir caracteres y combinaciones alemanas
convert_german_text() {
    echo "$1" | \
    sed -e 's/ä/ae/g' \
        -e 's/ö/oe/g' \
        -e 's/ü/ue/g' \
        -e 's/ß/ss/g' \
        -e 's/Ä/Ae/g' \
        -e 's/Ö/Oe/g' \
        -e 's/Ü/Ue/g' \
        -e 's/sch/sh/g' \
        -e 's/ch/kh/g' \
        -e 's/eu/oi/g' \
        -e 's/ei/ai/g'
}

# Convertir el texto
CONVERTED_TEXT=$(convert_german_text "$TEXT")

# Generar WAV usando Festival
echo "$CONVERTED_TEXT" | text2wave -o /tmp/f.wav
mpv /tmp/f.wav
