#!/bin/sh

# Minutos que recibimos como argumento
MINUTOS="$1"

# Validación de que sea un número entero
case "$MINUTOS" in
    ''|*[!0-9]*)
        echo "Uso: $0 <minutos>"
        exit 1
        ;;
esac

# Convertimos a segundos
SEGUNDOS=`expr "$MINUTOS" \* 60`

SEGUNDOS=$(($SEGUNDOS - 13))

while [ ! -f /tmp/.stop ]; do
    if [ "$SEGUNDOS" -le 0 ]; then
        break
    fi

    MIN=`expr "$SEGUNDOS" / 60`
    SEC=`expr "$SEGUNDOS" % 60`

    # Formateo con ceros a la izquierda
    [ "$MIN" -lt 10 ] && MSTR="0$MIN" || MSTR="$MIN"
    [ "$SEC" -lt 10 ] && SSTR="0$SEC" || SSTR="$SEC"

    # Mostramos en osd_cat
    echo "$MSTR:$SSTR alt+3 to exit" | osd_cat -p top -A center -d 1 -o 50 -c green

    SEGUNDOS=`expr "$SEGUNDOS" - 1`
done
