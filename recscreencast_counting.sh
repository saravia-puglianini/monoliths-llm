#!/bin/bash

# Limpieza al cancelar
trap 'cleanup' INT TERM

cleanup() {
    echo "⏹️ Limpiando procesos..."
    [ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null
    wait "$FFMPEG_PID" 2>/dev/null
    exit 1
}

echo "=============================="
echo "    Dispositivos de micrófono"
echo "=============================="
pactl list sources short
echo ""

printf "👉 Pega el nombre del micrófono (Enter = GRABAR SIN AUDIO): "
read -r MIC

RES=$(xrandr | grep '\*' | awk '{print $1}' | head -n 1)

if [ -z "$RES" ]; then
    echo "❌ Error: No se pudo obtener la resolución."
    exit 1
fi

SHORT_HASH=$(date +%s%N | md5sum | cut -c1-7)
BASE_NAME="$HOME/$(date +%Y-%m-%d_%H%M%S)_${SHORT_HASH}"
FILENAME="${BASE_NAME}.mp4"
TMP_MKV="/tmp/recscreencast_${SHORT_HASH}.mkv"

echo "⏳ Iniciando cuenta regresiva en pantalla..."

for i in 4 3 2 1; do
    echo "$i" | osd_cat -A center -p middle -d 1 -c red -f "-*-*-bold-*-*-*-120-*-*-*-*-*-*-*" 2>/dev/null &
    sleep 1
done

echo "¡GRABANDO!" | osd_cat -A center -p middle -d 1 -c green -f "-*-*-bold-*-*-*-80-*-*-*-*-*-*-*" 2>/dev/null &

if [ -z "$MIC" ]; then
    echo "⚠️  Grabando SOLO VIDEO (sin audio)..."
    echo "Resolución: $RES"
    
    ffmpeg -y -nostdin -thread_queue_size 5120 -f x11grab -framerate 30 -video_size "$RES" -i :0.0 \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           "$TMP_MKV" </dev/null >/tmp/ffmpeg_debug.log 2>&1 &
else
    # Extraer el nombre real del dispositivo si el usuario introdujo un número
    MIC_NAME=$(pactl list sources short | awk -v id="$MIC" '$1==id {print $2}')
    [ -z "$MIC_NAME" ] && MIC_NAME="$MIC" # Si no encuentra el número, asume que ya pegó el nombre
    
    echo "🔧 Configurando micrófono: $MIC_NAME"
    pactl set-default-source "$MIC_NAME"
    
    echo "🎥 Grabando con AUDIO..."
    echo "Resolución: $RES"
    echo "Micrófono: $MIC_NAME"
    
    ffmpeg -y -nostdin -thread_queue_size 5120 -f x11grab -framerate 30 -video_size "$RES" -i :0.0 \
           -thread_queue_size 5120 -f pulse -i "$MIC_NAME" \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           -c:a aac -b:a 128k -ac 2 -af "aresample=async=1" \
           "$TMP_MKV" </dev/null >/tmp/ffmpeg_debug.log 2>&1 &
fi

FFMPEG_PID=$!

# Verificar que ffmpeg esté corriendo
if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
    echo "❌ Error: ffmpeg no pudo iniciarse"
    exit 1
fi

echo "⏺️ Grabación iniciada (PID: $FFMPEG_PID)"

# Mostrar ventana de yad y esperar
YAD_OUT=$(yad --title="Grabación en Curso" \
              --text="🎥 <b>Grabando pantalla...</b>\n\nEscribe un identificador para agregar al final del nombre del video y presiona <b>Finalizar</b>." \
              --form \
              --field="Etiqueta del video (opcional):" \
              --button="⏹️ Finalizar:0" \
              --on-top \
              --center </dev/null 2>/dev/null)

echo "⏹️ Deteniendo la grabación correctamente..."

# Detener ffmpeg de forma controlada usando SIGINT (equivalente a presionar 'q')
kill -INT "$FFMPEG_PID" 2>/dev/null

# Esperar a que ffmpeg termine de escribir el archivo
echo "⏳ Esperando que ffmpeg finalice la escritura del archivo MKV temporal..."
wait "$FFMPEG_PID" 2>/dev/null

echo "🔄 Convirtiendo a MP4 de forma segura..."
# Remuxear a MP4. Esto es casi instantáneo y asegura un archivo MP4 100% válido y sin problemas de cabeceras.
ffmpeg -y -i "$TMP_MKV" -c copy -movflags +faststart "$FILENAME" </dev/null >/dev/null 2>&1

# Limpiar el archivo MKV temporal
rm -f "$TMP_MKV"

# Verificar que el archivo existe y tiene tamaño
if [ -f "$FILENAME" ]; then
    FILE_SIZE=$(stat -c%s "$FILENAME" 2>/dev/null || stat -f%z "$FILENAME" 2>/dev/null)
    echo "📊 Tamaño del archivo: $(($FILE_SIZE / 1024 / 1024)) MB"
fi

SUFFIX=$(echo "$YAD_OUT" | awk -F'|' '{print $1}')

if [ -n "$SUFFIX" ]; then
    CLEAN_SUFFIX=$(echo "$SUFFIX" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
    NEW_FILENAME="${BASE_NAME}_${CLEAN_SUFFIX}.mp4"
    
    mv "$FILENAME" "$NEW_FILENAME"
    echo "✅ Grabación finalizada exitosamente."
    echo "📂 Archivo guardado: $NEW_FILENAME"
else
    echo "✅ Grabación finalizada exitosamente."
    echo "📂 Archivo guardado: $FILENAME"
fi

echo ""
exit 0