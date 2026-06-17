#!/bin/dash

echo "=============================="
echo "    Dispositivos de micrófono"
echo "=============================="
pactl list sources short
echo ""

printf "👉 Pega el nombre del micrófono (Enter = GRABAR SIN AUDIO): "
read MIC

RES=$(xrandr | grep '\*' | awk '{print $1}' | head -n 1)

if [ -z "$RES" ]; then
    echo "❌ Error: No se pudo obtener la resolución de la pantalla. Asegúrate de tener xrandr instalado."
    exit 1
fi

# Generamos un hash corto basado en la fecha y nanosegundos para evitar duplicados
SHORT_HASH=$(date +%s%N | md5sum | cut -c1-7)

# El nombre: Año primero, luego mes/día, hora y el hash
FILENAME="$HOME/$(date +%Y-%m-%d_%H%M%S)_${SHORT_HASH}.mp4"

if [ -z "$MIC" ]; then
    echo "⚠️  Grabando SOLO VIDEO (sin audio)..."
    echo "Resolución: $RES"
    
    # Comando sin entradas de audio
    ffmpeg -f x11grab -thread_queue_size 1024 -framerate 30 -video_size "$RES" -i :0.0 \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           -movflags +faststart \
           "$FILENAME"
else
    echo "🔧 Configurando micrófono: $MIC"
    pactl set-default-source "$MIC"
    
    echo "🎥 Grabando con AUDIO..."
    echo "Resolución: $RES"
    echo "Micrófono: $MIC"
    
    # Comando original con audio Pulse
    ffmpeg -f x11grab -thread_queue_size 1024 -framerate 30 -video_size "$RES" -i :0.0 \
           -f pulse -thread_queue_size 1024 -i "$MIC" \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           -c:a aac -b:a 128k -ac 2 \
           -movflags +faststart \
           "$FILENAME"
fi