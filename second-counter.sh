#!/bin/sh

SEGUNDOS="$1"

while [ ! -f /tmp/.stop ]; do
    if [ "$SEGUNDOS" -le 0 ]; then
        break
    fi
    SEC=`expr "$SEGUNDOS" % 60`
    # Formateo con ceros a la izquierda
    [ "$SEC" -lt 10 ] && SSTR="0$SEC" || SSTR="$SEC"
    # Mostramos en osd_cat
    echo "Start in $SSTR alt+3 to exit" | osd_cat -p top -A center -d 1 -o 50 -c green -f '-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso8859-1'

    SEGUNDOS=`expr "$SEGUNDOS" - 1`
done
