#!/bin/sh
# Archivo: tts_spanish.sh

# Texto de entrada
TEXT="$1"
FILE="$2"

# Función para convertir caracteres españoles para que suenen mejor con voz inglesa
convert_spanish_text() {
echo "$1" | sed -e 's/á/a/g' \
    -e 's/é/e/g' \
    -e 's/í/i/g' \
    -e 's/ó/o/g' \
    -e 's/ú/u/g' \
    -e 's/ü/u/g' \
    -e 's/ñ/ny/g' \
    -e 's/Ñ/Ny/g' \
    -e 's/ll/y/g' \
    -e 's/j/h/g' \
    -e 's/ch/tch/g' \
    -e 's/ce/s/g' \
    -e 's/ci/s/g' \
    -e 's/g[ei]/kh/g' \
    -e 's/qu/k/g' \
    -e 's/z/s/g' \
    -e 's/v/b/g' \
    -e 's/mu/moo/g' \
    -e 's/tu/too/g' \
    -e 's/pu/poo/g' \
    -e 's/ y / i /g' \
    -e 's/\bse\b/seh/g' \
    -e 's/\bte\b/teh/g' \
    -e 's/\bme\b/meh/g' \
    -e 's/\ble\b/leh/g' \
    -e 's/\bque\b/kay/g' \
    -e 's/\bqui\b/kee/g' \
    -e 's/\bqu\b/k/g' \
    -e 's/e\b/eh/g' \
    -e 's/a\b/ah/g' \
    -e 's/o\b/oh/g' \
    -e 's/\bun\b/oon/g' \
    -e 's/ll/y/g' \          # ll → y
    -e 's/tt/t/g' \          # t doble → t simple
    -e 's/a\b/ah/g'          # a final → ah
}

# Convertir el texto
CONVERTED_TEXT=$(convert_spanish_text "$TEXT")

# Generar WAV usando Festival

echo "$CONVERTED_TEXT" | text2wave -o /tmp/f.wav
mpv /tmp/f.wav

