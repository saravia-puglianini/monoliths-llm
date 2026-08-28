#!/bin/bash
set -o pipefail

# Da tiempo para terminar el gesto de ventanas y dejar al frente la ventana
# que se quiere capturar.
(for i in 5 4 3 2 1; do echo "  $i  "; sleep 1; done) |
    osd_cat --color=red --delay=1 --align=right --pos=top --offset=50

# Consulta el foco después del conteo, cuando el gesto de ventanas ya terminó,
# y captura solamente esa ventana con import.
focused_window=$(xdotool getactivewindow) || focused_window=

if [ -z "$focused_window" ] ||
   ! import -window "$focused_window" png:- |
       xclip -selection clipboard -t image/png; then
    yad --title='Error' --text='Fallo la captura de pantalla completa' --button=OK:0
    exit 1
fi
