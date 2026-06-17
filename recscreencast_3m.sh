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

SHORT_HASH=$(date +%s%N | md5sum | cut -c1-7)
FILENAME="$HOME/$(date +%Y-%m-%d_%H%M%S)_${SHORT_HASH}.mp4"

echo "⏳ Preparando grabación de 1 minuto exacto..."

# ==========================================
#   CRONÓMETRO EN PANTALLA (SEGUNDO PLANO)
# ==========================================
# Encapsulamos el bucle en paréntesis y le ponemos '&' al final 
# para que corra en segundo plano sin bloquear a ffmpeg.
(
    i=179
    while [ $i -ge 0 ]; do
        # Formatea el número para asegurar los dos ceros (ej: 00:09, 00:59)
        TIME_STR=$(printf "%02dseg." "$i")
        
        # -p top (arriba) | -A right (derecha) | -O 20 (margen/offset para que no pegue en el borde)
        echo "$TIME_STR" | osd_cat -p top -A right -O 20 -d 1 -c red -f "-*-*-bold-*-*-*-80-*-*-*-*-*-*-*" &
        sleep 1
        
        i=$((i - 1))
    done
) &
# Guardamos el ID del proceso del cronómetro por si necesitamos detenerlo
TIMER_PID=$!
# ==========================================

if [ -z "$MIC" ]; then
    echo "⚠️  Grabando SOLO VIDEO por 180 segundos..."
    
    # Se añade "-t 180" justo antes del archivo de salida para limitar la duración
    ffmpeg -nostdin -f x11grab -thread_queue_size 1024 -framerate 30 -video_size "$RES" -i :0.0 \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           -movflags +faststart \
           -t 180 \
           "$FILENAME"
else
    echo "🔧 Configurando micrófono: $MIC"
    pactl set-default-source "$MIC"
    
    echo "🎥 Grabando con AUDIO por 180 segundos..."
    
    # Se añade "-t 180" justo antes del archivo de salida
    ffmpeg -nostdin -f x11grab -thread_queue_size 1024 -framerate 30 -video_size "$RES" -i :0.0 \
           -f pulse -thread_queue_size 1024 -i "$MIC" \
           -c:v libx264 -preset veryfast -pix_fmt yuv420p \
           -c:a aac -b:a 128k -ac 2 \
           -movflags +faststart \
           -t 180 \
           "$FILENAME"
fi

# Nos aseguramos de matar el proceso del cronómetro si detienes ffmpeg manualmente (Ctrl+C) antes del minuto
kill $TIMER_PID 2>/dev/null

echo "✅ Grabación finalizada y guardada en: $FILENAME"