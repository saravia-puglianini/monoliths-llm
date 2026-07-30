#!/bin/dash

# Mostrar un cuadro de diálogo para ingresar un entero
num=$(yad --entry \
	  --title='Ingrese un numero entero mayor a 2 (Minutos)' \
	  --text='Escriba un numero entero mayor a 2 (Minutos):' \
	  --entry-text='0' \
	  --width=300 \
	  --height=100)

# Comprobar que se ingresó algo
if [ -n "$num" ]; then
    # Ejecutar el script con el número ingresado
    dash $HOME/monoliths-llm/training-on-left-seconds-a-range-of-N-minute.sh $num
fi
