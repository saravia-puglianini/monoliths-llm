#!/bin/dash

num=$(yad --entry \
  --title='Ingrese un numero entero (Segundos)' \
  --text='Escriba un numero entero (Segundos) o use los botones:' \
  --entry-text='0' \
  --width=350 \
  --height=120 \
  --button='1m:10' \
  --button='4m:11' \
  --button='15m:12' \
  --button='Aceptar:0' \
  --button='Cancelar:1')

ret=$?

case "$ret" in
    0)  # Aceptar (valor escrito)
        [ -n "$num" ] && dash "$HOME/monoliths-llm/simple_second_counter-N.sh" "$num"
        ;;
    10) # 1 minuto
        dash "$HOME/monoliths-llm/simple_second_counter-N.sh" 60
        ;;
    11) # 4 minutos
        dash "$HOME/monoliths-llm/simple_second_counter-N.sh" 360
        ;;
    12) # 15 minutos
        dash "$HOME/monoliths-llm/simple_second_counter-N.sh" 900
        ;;
esac
