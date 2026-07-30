#!/bin/dash

# Duración total en segundos (primer argumento)
DURATION=$1

# Tamaño de la barra
BAR_LENGTH=20

# Validar que se pase un argumento
if [ -z "$DURATION" ]; then
  echo "Uso: $0 <segundos>"
  exit 1
fi

# Calcular tiempo por 'paso' de la barra
STEP_TIME=$(echo "$DURATION / $BAR_LENGTH" | bc -l)

for i in $(seq 0 $BAR_LENGTH); do
  # Cantidad de '=' y '_'
  FILLED=$(printf '%0.s=' $(seq 1 $i))
  EMPTY=$(printf '%0.s_' $(seq 1 $((BAR_LENGTH - i))))
  
  # Mostrar barra
  printf "\r[%s%s]" "$FILLED" "$EMPTY"
  
  # Esperar el tiempo del paso
  sleep $STEP_TIME
done

# Nueva línea al terminar
echo