#!/bin/dash

# Duración total en segundos (primer argumento)
DURATION=$1

# Validar que se pase un argumento
if [ -z "$DURATION" ]; then
  echo "Uso: $0 <segundos>"
  exit 1
fi

# Calcular tiempo entre imágenes (considerando 21 imágenes: 0, 5, 10, ..., 100)
NUM_IMAGES=21
STEP_TIME=$(awk "BEGIN {print $DURATION / ($NUM_IMAGES - 1)}")

# Mostrar las imágenes
for i in $(seq 0 $((NUM_IMAGES - 1))); do
  # Calcular número de imagen (0, 5, 10, ..., 100)
  IMG_NUM=$((i * 5))
  
  # Construir nombre del archivo
  IMG_FILE="$HOME/monoliths-hm/${IMG_NUM}.jpg"
  
  # Verificar si el archivo existe
  if [ -f "$IMG_FILE" ]; then
    # Cerrar display anterior si está abierto
    pkill -x display 2>/dev/null
    
    # Mostrar nueva imagen (en segundo plano) con ImageMagick display
    display -window root "$IMG_FILE" &
    
    # Registrar el PID para poder cerrarlo después
    DISP_PID=$!
  else
    echo "Advertencia: Archivo $IMG_FILE no encontrado"
  fi
  
  # Esperar el tiempo calculado (excepto en la última iteración)
  if [ $i -lt $((NUM_IMAGES - 1)) ]; then
    sleep $STEP_TIME
  fi
done

# Cerrar la última imagen después de la duración total
sleep $STEP_TIME
pkill -x display 2>/dev/null

echo 'Presentación completada'