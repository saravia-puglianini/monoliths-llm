#!/bin/dash
# festival_de_ffmpeg.sh
TEXTO="$1"
SALIDA="$2"
TMP_RAW='/tmp/festival_de_raw.wav'

if [ -z "$TEXTO" ] || [ -z "$SALIDA" ]; then
    echo "Uso: $0 \"texto en alemán\' salida.wav'
    exit 1
fi

# Generar WAV con voz inglesa
echo "$TEXTO" | text2wave -o "$TMP_RAW" -eval "(set! voice_default 'kal_diphone)"

# Ajustar velocidad/pitch/volumen
ffmpeg -y -i "$TMP_RAW" -af 'asetrate=44100*0.95,aresample=44100,volume=1.4' "$SALIDA"

rm "$TMP_RAW"
