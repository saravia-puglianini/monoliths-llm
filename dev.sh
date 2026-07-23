#!/bin/bash

# Colors for nice output if in a terminal
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    GREEN=''
    BLUE=''
    BOLD=''
    NC=''
fi

echo -e "${BOLD}Input Devices Mapping in /dev/input/:${NC}"
echo "--------------------------------------------------"

touchpad_found=false

for dev in /dev/input/*; do
    # Skip directories, check if character device
    if [ -c "$dev" ]; then
        name=$(basename "$dev")
        sys_path="/sys/class/input/$name"
        
        device_name=""
        phys=""
        
        # Read from device uevent if it exists
        if [ -f "$sys_path/device/uevent" ]; then
            device_name=$(grep '^NAME=' "$sys_path/device/uevent" | cut -d'"' -f2)
            phys=$(grep '^PHYS=' "$sys_path/device/uevent" | cut -d'"' -f2)
        fi
        
        # Fallbacks for specific virtual/special devices
        if [ -z "$device_name" ]; then
            if [ "$name" = "mice" ]; then
                device_name="System Mouse Multiplexer (mice)"
            else
                device_name="Unknown Device"
            fi
        fi
        
        if [[ "${device_name,,}" =~ (touchpad|synaptics|alps|glidepoint|elantech) ]]; then
            touchpad_found=true
        fi
        
        if [ -n "$phys" ]; then
            echo -e "  ${GREEN}$dev${NC} -> ${BOLD}$device_name${NC} (Phys: $phys)"
        else
            echo -e "  ${GREEN}$dev${NC} -> ${BOLD}$device_name${NC}"
        fi
    fi
done
echo "--------------------------------------------------"

if [ "$touchpad_found" = true ]; then
    echo -e "${GREEN}${BOLD}* SE HA DETECTADO UN TOUCHPAD EN EL SISTEMA.${NC}"
else
    echo -e "${BLUE}${BOLD}* NOTA: Actualmente no se ha identificado un touchpad en el hardware.${NC}"
    echo "  Ejemplos de cómo debería verse si se detectara hardware de touchpad:"
    echo "    /dev/input/eventX -> Synaptics TM3337-002 (Phys: isa0060/serio2/input0)"
    echo "    /dev/input/eventX -> ETPS/2 Elantech Touchpad (Phys: isa0060/serio1/input0)"
    echo "    /dev/input/eventX -> ELAN0100:00 04F3:309F Touchpad (Phys: i2c-ELAN0100:00)"
fi

