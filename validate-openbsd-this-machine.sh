#!/bin/bash
# Validador de compatibilidad para OpenBSD corriendo en Linux

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}=================================================="
echo -e "      VALIDADOR DE COMPATIBILIDAD CON OPENBSD"
echo -e "==================================================${NC}"
echo ""

# Verificar herramientas requeridas
for cmd in lspci grep awk; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}[ERROR] El comando '$cmd' es requerido pero no está instalado.${NC}"
        exit 1
    fi
done

# 1. CPU & Virtualización
echo -e "${BOLD}1. Procesador y Arquitectura:${NC}"
ARCH=$(uname -m)
echo "   - Arquitectura: $ARCH"
if [[ "$ARCH" == "x86_64" || "$ARCH" == "x86" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
    echo -e "     ${GREEN}[APTO] Totalmente compatible (amd64 / i386).${NC}"
elif [[ "$ARCH" == *"arm"* || "$ARCH" == "aarch64" ]]; then
    echo -e "     ${GREEN}[APTO] Compatible con la arquitectura ARM64/ARMv7 (Raspberry Pi, etc.).${NC}"
else
    echo -e "     ${YELLOW}[DUDOSO] Arquitectura no estándar para OpenBSD o soporte experimental.${NC}"
fi

# Soporte de virtualización para vmm/vmd (requiere vmx/svm)
if grep -E -q "vmx|svm" /proc/cpuinfo 2>/dev/null; then
    echo -e "     Soporte para vmm/vmd (VT-x/SVM): ${GREEN}Soportado (Puedes usar virtualización nativa vmm/vmd en OpenBSD)${NC}"
else
    echo -e "     Soporte para vmm/vmd (VT-x/SVM): ${YELLOW}No detectado (No podrás usar el hipervisor nativo vmm)${NC}"
fi
echo ""

# 2. Memoria RAM
echo -e "${BOLD}2. Memoria RAM:${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
echo "   - Memoria detectada: ${TOTAL_RAM_MB} MB"
if [ $TOTAL_RAM_MB -lt 256 ]; then
    echo -e "     ${RED}[CRÍTICO] RAM insuficiente para una instalación cómoda.${NC}"
elif [ $TOTAL_RAM_MB -lt 512 ]; then
    echo -e "     ${YELLOW}[APTO (MÍNIMO)] OpenBSD correrá sin problemas en modo consola, pero con entorno gráfico puede estar ajustado.${NC}"
else
    echo -e "     ${GREEN}[APTO] Memoria RAM suficiente para OpenBSD (incluso con entorno gráfico Xenocara/Fvwm).${NC}"
fi
echo ""

# 3. Dispositivos PCI y Controladores
echo -e "${BOLD}3. Dispositivos de Hardware Críticos:${NC}"

check_pci_device() {
    local label="$1"
    local class_pattern="$2"
    
    echo -e "   ${BOLD}* $label:${NC}"
    
    local devices=$(lspci -nn | grep -i -E "$class_pattern")
    
    if [ -z "$devices" ]; then
        echo "     No se detectaron dispositivos de este tipo."
        return
    fi
    
    while IFS= read -r dev; do
        echo "     - $dev"
        if [[ $dev =~ \[([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\] ]]; then
            local vendor="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            
            # Comprobación de fabricante y sugerencias de drivers
            if [[ "$vendor" == "8086" ]]; then
                if [[ "$label" == *"Video"* ]]; then
                    echo -e "       ${GREEN}[SOPORTADO] Gráficos Intel. Excelente soporte nativo (inteldrm).${NC}"
                elif [[ "$label" == *"Inalámbrica"* ]]; then
                    echo -e "       ${GREEN}[SOPORTADO] Wi-Fi Intel. Soportado (iwm/iwx/iwn). Requiere firmware privativo que se descarga automáticamente con fw_update(8).${NC}"
                else
                    echo -e "       ${GREEN}[SOPORTADO] Dispositivo Intel. Excelente soporte y estabilidad en OpenBSD.${NC}"
                fi
            elif [[ "$vendor" == "10de" ]] && [[ "$label" == *"Video"* ]]; then
                echo -e "       ${RED}[LIMITADO] GPU NVIDIA. OpenBSD NO soporta drivers propietarios de NVIDIA. Deberás usar el driver genérico VESA o el driver libre 'nouveau' (sin aceleración 3D moderna).${NC}"
            elif [[ "$vendor" == "1002" || "$vendor" == "1022" ]] && [[ "$label" == *"Video"* ]]; then
                echo -e "       ${GREEN}[SOPORTADO] GPU AMD/Radeon. Buen soporte mediante driver libre (amdgpu/radeondrm).${NC}"
            elif [[ "$vendor" == "14c3" || "$vendor" == "10ec" || "$vendor" == "14e4" ]] && [[ "$label" == *"Inalámbrica"* ]]; then
                echo -e "       ${YELLOW}[ADVERTENCIA] Tarjeta Wi-Fi Realtek/Broadcom/MediaTek. El soporte varía; muchas requieren firmware privativo. Si no tienes conexión ethernet durante la instalación, deberás cargar el firmware manualmente desde un pendrive.${NC}"
            elif [[ "$vendor" == "10ec" ]] && [[ "$label" == *"Ethernet"* ]]; then
                echo -e "       ${GREEN}[SOPORTADO] Ethernet Realtek. Soportado nativamente por el driver re(4).${NC}"
            fi
        fi
    done <<< "$devices"
}

check_pci_device "Controlador de Video (Gráficos)" "vga|display|3d"
check_pci_device "Controlador de Red (Ethernet)" "ethernet"
check_pci_device "Controlador de Red Inalámbrica (Wi-Fi)" "network|wireless"
check_pci_device "Controlador de Almacenamiento (SATA/AHCI/NVMe)" "sata|ahci|non-volatile|storage"
check_pci_device "Controlador de Audio" "audio|sound|multimedia"

echo ""
echo -e "${BOLD}4. Conclusión / Recomendación para OpenBSD:${NC}"
echo "   - Para probar OpenBSD de forma segura, puedes usar QEMU/KVM en Linux:"
echo -e "     ${BLUE}qemu-system-x86_64 -m 1024 -enable-kvm -cpu host -smp 2 -net nic,model=virtio -net user -drive file=openbsd.qcow2,media=disk,if=virtio -cdrom install75.iso -boot d${NC}"
echo ""
