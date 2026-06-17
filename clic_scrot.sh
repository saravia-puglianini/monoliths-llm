#!/bin/bash
# Guardar como ~/bin/capture-on-click.sh
# chmod +x ~/bin/capture-on-click.sh

while true; do
    # Esperar a que se presione el botón del ratón (botón 3 = clic derecho)
    # xdotool espera sin bloquear el sistema
    xdotool behave_screen_edge --delay 100 \
        exec sh -c '
            sleep 0.1  # Pequeña pausa para evitar capturar el mismo clic
            scrot -s -o - | \
            tesseract stdin stdout -l eng | \
            tr "\n" " " | \
            xargs -0 -I {} ~/literatura/googletrans-es "{}" | \
            $HOME/piper/piper --model $HOME/piper/es_MX-claude-high.onnx --output_file - | \
            mpv --no-video -
        '
    sleep 0.1
done