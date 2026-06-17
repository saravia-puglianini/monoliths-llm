#!/bin/bash
# Validador de compatibilidad para Plan 9 / 9front en Linux

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}=================================================="
echo -e "   VALIDADOR DE COMPATIBILIDAD CON PLAN 9 / 9FRONT"
echo -e "==================================================${NC}"
echo ""

# Verificar herramientas requeridas
for cmd in curl lspci grep; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}[ERROR] El comando '$cmd' es requerido pero no está instalado.${NC}"
        exit 1
    fi
done

# Descargar las páginas de compatibilidad de la FQA de 9front para búsqueda local
FQA_CACHE="/tmp/9front_fqa_cache.html"
echo -n "Descargando base de datos de compatibilidad de 9front FQA... "
if curl -s -o "$FQA_CACHE" http://fqa.9front.org/fqa3.html; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}ADVERTENCIA: No se pudo conectar a fqa.9front.org. Las comprobaciones de ID de hardware se omitirán.${NC}"
    FQA_CACHE=""
fi
echo ""

# 1. CPU & Virtualización
echo -e "${BOLD}1. Procesador y Arquitectura:${NC}"
ARCH=$(uname -m)
echo "   - Arquitectura: $ARCH"
if [[ "$ARCH" == "x86_64" || "$ARCH" == "x86" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
    echo -e "     ${GREEN}[APTO] Compatible con las versiones x86/amd64 de 9front.${NC}"
elif [[ "$ARCH" == *"arm"* || "$ARCH" == "aarch64" ]]; then
    echo -e "     ${GREEN}[APTO] Compatible con la arquitectura ARM de 9front (Raspberry Pi, etc.).${NC}"
else
    echo -e "     ${YELLOW}[DUDOSO] Arquitectura no estándar para Plan 9.${NC}"
fi

# Soporte de virtualización por hardware (para QEMU/VirtualBox)
if grep -E -q "vmx|svm" /proc/cpuinfo 2>/dev/null; then
    echo -e "     Virtualización por Hardware (VT-x/SVM): ${GREEN}Soportado (Excelente para QEMU/KVM)${NC}"
else
    echo -e "     Virtualización por Hardware (VT-x/SVM): ${YELLOW}No detectado o deshabilitado${NC}"
fi
echo ""

# 2. Memoria RAM
echo -e "${BOLD}2. Memoria RAM:${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
echo "   - Memoria detectada: ${TOTAL_RAM_MB} MB"
if [ $TOTAL_RAM_MB -lt 128 ]; then
    echo -e "     ${RED}[CRÍTICO] RAM insuficiente para una instalación cómoda.${NC}"
elif [ $TOTAL_RAM_MB -lt 512 ]; then
    echo -e "     ${YELLOW}[APTO (MÍNIMO)] Plan 9 puede correr con poca RAM, pero se recomienda más.${NC}"
else
    echo -e "     ${GREEN}[APTO] Memoria RAM más que suficiente.${NC}"
fi
echo ""

# 3. Dispositivos PCI (Comprobación de compatibilidad con la FQA)
echo -e "${BOLD}3. Dispositivos de Hardware Críticos:${NC}"

check_pci_device() {
    local label="$1"
    local class_pattern="$2"
    
    echo -e "   ${BOLD}* $label:${NC}"
    
    # Obtener dispositivos que coincidan con la clase PCI
    local devices=$(lspci -nn | grep -i -E "$class_pattern")
    
    if [ -z "$devices" ]; then
        echo "     No se detectaron dispositivos de este tipo."
        return
    fi
    
    while IFS= read -r dev; do
        echo "     - $dev"
        # Extraer VendorID y DeviceID, ej. [8086:46a8] -> vendor 8086, device 46a8
        if [[ $dev =~ \[([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\] ]]; then
            local vendor="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            local vid_did="${vendor}/${device}"
            
            if [ -n "$FQA_CACHE" ]; then
                # Buscar vid/did en la FQA
                if grep -i -q "$vid_did" "$FQA_CACHE"; then
                    echo -e "       ${GREEN}[COMPATIBLE] Encontrado en la lista oficial de 9front FQA ($vid_did).${NC}"
                else
                    # Comprobaciones generales por fabricante
                    if [[ "$vendor" == "8086" ]]; then
                        echo -e "       ${GREEN}[PROBABLE] Chipset Intel ($vid_did). Excelente compatibilidad en Plan 9 / 9front.${NC}"
                    elif [[ "$vendor" == "14c3" || "$vendor" == "10ec" ]] && [[ "$label" == *"Inalámbrica"* ]]; then
                        echo -e "       ${YELLOW}[ADVERTENCIA] Tarjeta Wi-Fi ($vid_did). El soporte inalámbrico en 9front es limitado; se prefiere ethernet o tethering.${NC}"
                    else
                        echo -e "       ${YELLOW}[DESCONOCIDO] No listado explícitamente en la FQA ($vid_did). Podría requerir drivers genéricos (VESA, AC97, etc.).${NC}"
                    fi
                fi
            else
                echo "       Sin comprobación de FQA (modo offline)."
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
echo -e "${BOLD}4. Conclusión / Recomendación:${NC}"
echo "   - Para una experiencia fluida y sin riesgos en tu hardware real, se recomienda usar una máquina virtual (QEMU)."
echo "   - Comando recomendado para ejecutar 9front en QEMU:"
echo -e "     ${BLUE}qemu-system-x86_64 -m 2048 -enable-kvm -net nic,model=virtio -net user -soundhw hda -drive file=9front.qcow2,media=disk -cdrom 9front.iso -boot d${NC}"
echo ""

# Limpieza
rm -f "$FQA_CACHE"