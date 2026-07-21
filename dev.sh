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
        
        if [ -n "$phys" ]; then
            echo -e "  ${GREEN}$dev${NC} -> ${BOLD}$device_name${NC} (Phys: $phys)"
        else
            echo -e "  ${GREEN}$dev${NC} -> ${BOLD}$device_name${NC}"
        fi
    fi
done
echo "--------------------------------------------------"
