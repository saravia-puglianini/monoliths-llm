#!/bin/bash
# 1. Countdown direkt starten
(for i in 5 4 3 2 1; do echo "  $i  "; sleep 1; done) | osd_cat --color=red --delay=1 --align=right --pos=top --offset=50

# 2. Ohne Verzögerung sofort die Aufnahme machen
cd ~
scrot -p -e 'xclip -selection clipboard -t image/png -i $f && rm $f' || yad --title='Error' --text='Fallo la captura de pantalla completa' --button=OK:0