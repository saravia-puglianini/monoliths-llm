#!/bin/dash
# Nombre exacto del dispositivo según xinput list
DEVICE="ELAN0791:00 04F3:30FD Touchpad"

# Obtenemos el estado actual del dispositivo (1 = encendido, 0 = apagado)
# Usamos awk para extraer el último valor de la línea "Device Enabled"
STATE=$(xinput list-props "$DEVICE" | grep "Device Enabled" | awk '{print $NF}')

# Evaluamos el estado y lo cambiamos
if [ "$STATE" = "1" ]; then
    xinput disable "$DEVICE"
    echo "Touchpad desactivado."
elif [ "$STATE" = "0" ]; then
    xinput enable "$DEVICE"
    echo "Touchpad activado."
else
    echo "Error: No se pudo determinar el estado actual del touchpad."
    exit 1
fi
DEVICE="ELAN0791:00 04F3:30FD Touchpad"
# Usamos las propiedades de Synaptics detectadas (MinSpeed, MaxSpeed, AccelFactor)
# Valores originales: 1.0 1.75 0.05 -> Duplicamos para mas rapidez
xinput --set-prop "$DEVICE" "Synaptics Move Speed" 2.0 4.0 0.15 0.0
echo "Velocidad del touchpad aumentada (Synaptics)."
# Buscar si existe el respaldo temporal
TEMP_BACKUP=$(ls $HOME/.xbindkeysrc.*.tmp 2>/dev/null | head -n 1)
if [ -n "$TEMP_BACKUP" ]; then
    # Modo Restauración: Regresar al original
    rm -f "$HOME/.xbindkeysrc"
    mv "$TEMP_BACKUP" "$HOME/.xbindkeysrc"
    killall xbindkeys 2>/dev/null
    xbindkeys
    echo "Configuración original de xbindkeysrc restaurada."
else
    # Modo Activación: Crear configuración temporal
    TIMESTAMP=$(date +%s)
    if [ -f "$HOME/.xbindkeysrc" ]; then
	mv "$HOME/.xbindkeysrc" "$HOME/.xbindkeysrc.$TIMESTAMP.tmp"
	echo "Respaldo creado: .xbindkeysrc.$TIMESTAMP.tmp"
    fi
    # Crear nueva config con Alt+1 (OFF) y Alt+2 (ON)
    cat <<EOF > "$HOME/.xbindkeysrc"
# Touchpad Switcher Mode
"xinput disable 'ELAN0791:00 04F3:30FD Touchpad'"
    alt + 1

"xinput enable 'ELAN0791:00 04F3:30FD Touchpad'"
    alt + 2

"sleep 0.5 && ([ -f /tmp/_xcalib_working ] && rm /tmp/_xcalib_working || touch /tmp/_xcalib_working ) ; xcalib -i -a"
    alt + 5
EOF
    killall xbindkeys 2>/dev/null
    xbindkeysrc -f "$HOME/.xbindkeysrc"
    echo "Modo Touchpad Switcher activado: Alt+1 (Apagar), Alt+2 (Encender)."
fi
if [ -f /tmp/_xcalib_working ]; then
    rm /tmp/_xcalib_working
fi
sleep 0.5 && xcalib -i -a
