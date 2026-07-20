#!/bin/bash
# Apagar la pantalla usando xset (servidor X11)
xset dpms force off

# Ejecutar el script que toma el control exclusivo del teclado y espera corriente/Enter
doas python3 /home/user/suspender.py

# Encender la pantalla de nuevo
xset dpms force on
xset s reset
