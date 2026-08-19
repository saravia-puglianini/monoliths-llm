#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/my.shell.sh
# Menú de selección interactiva para perfiles de audio y utilidades a demanda
# ==============================================================================

DIR_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Comprobar si tenemos interfaz gráfica disponible y herramientas
has_gui() {
    [ -n "$DISPLAY" ] && command -v yad >/dev/null 2>&1
}

has_dialog() {
    command -v dialog >/dev/null 2>&1
}

ejecutar_perfil() {
    local script_name="$1"
    local desc="$2"
    local script_path="${DIR_BASE}/${script_name}"

    if [ ! -f "$script_path" ]; then
        echo "Error: No se encontró el script $script_path"
        return 1
    fi

    echo ">>> Ejecutando: $desc ($script_name)..."
    bash "$script_path"
    local res=$?
    
    if [ $res -eq 0 ]; then
        echo "✔ Perfil activado correctamente."
        if has_gui; then
            yad --title="Audio Configurado" \
                --image="audio-volume-high" \
                --text="<b>Perfil Activado:</b>\n\n$desc\n(<i>$script_name</i>)" \
                --button="Aceptar:0" \
                --timeout=3 \
                --center 2>/dev/null || true
        fi
    else
        echo "✘ Error al activar el perfil (código $res)."
    fi
}

# ------------------------------------------------------------------------------
# MENÚ CON YAD (Gráfico)
# ------------------------------------------------------------------------------
menu_yad() {
    while true; do
        SELECCION=$(yad --title="Menú Principal - Perfiles de Audio & Shell" \
            --window-icon="audio-speakers" \
            --width=720 \
            --height=480 \
            --center \
            --list \
            --radiolist \
            --column="Sel" \
            --column="ID" \
            --column="Perfil Resumido" \
            --column="Detalles / Descripción" \
            FALSE "1" "SOF Interno" "Salida Altavoces Laptop + Micrófono Interno Laptop" \
            FALSE "2" "SOF Filtro" "Salida Altavoces Laptop + Micrófono Interno con Filtro DSP" \
            TRUE  "3" "JBL Directo" "Salida Audífonos JBL + Captura Micrófono JBL Wireless" \
            FALSE "4" "JBL Filtro" "Salida Audífonos JBL + Captura Mic JBL con Filtro DSP" \
            FALSE "5" "JBL Loopback Mic-JBL" "Salida JBL + Mic JBL + Monitoreo propio Mic JBL en auriculares" \
            FALSE "6" "JBL Filtro-Loopback Mic-JBL" "Salida JBL + Mic JBL + Monitoreo propio Mic JBL con Filtro" \
            FALSE "7" "JBL Loopback Mic-Laptop" "Salida JBL + Mic JBL + Monitoreo Mic Interno Laptop en auriculares" \
            FALSE "8" "JBL Filtro-Loopback Mic-Laptop" "Salida JBL + Mic JBL + Monitoreo Mic Laptop Filtrado en auriculares" \
            FALSE "9" "QA Test Suite" "Ejecutar Plan Completo de Pruebas QA Interactivas" \
            --button="Salir:1" \
            --button="Ejecutar Perfil:0" \
            --separator="|" 2>/dev/null)

        local status=$?
        [ $status -ne 0 ] && break

        ID=$(echo "$SELECCION" | awk -F'|' '{print $2}')
        procesar_opcion "$ID"
    done
}

# ------------------------------------------------------------------------------
# MENÚ CON DIALOG (Terminal / TTY)
# ------------------------------------------------------------------------------
menu_dialog() {
    while true; do
        ID=$(dialog --title "Menú Principal - Perfiles de Audio & Shell" \
            --menu "Selecciona el perfil de audio que deseas activar:" 18 78 9 \
            "1" "SOF Interno (Out Laptop / In Laptop)" \
            "2" "SOF Filtro (Out Laptop / In Laptop + Filtro DSP)" \
            "3" "JBL Directo (Out JBL / In JBL Mic)" \
            "4" "JBL Filtro (Out JBL / In JBL Mic + Filtro DSP)" \
            "5" "JBL Loopback Mic-JBL (Monitoreo Mic JBL en auriculares)" \
            "6" "JBL Filtro-Loopback Mic-JBL (Monitoreo Mic JBL Filtrado)" \
            "7" "JBL Loopback Mic-Laptop (Monitoreo Mic Laptop en JBL)" \
            "8" "JBL Filtro-Loopback Mic-Laptop (Monitoreo Mic Laptop Filtrado)" \
            "9" "QA Test Suite (Ejecutar Suite Completa de Pruebas)" \
            3>&1 1>&2 2>&3)

        local status=$?
        clear
        [ $status -ne 0 ] && break

        procesar_opcion "$ID"
        echo ""
        read -r -p "Presiona [Enter] para volver al menú..."
    done
}

# ------------------------------------------------------------------------------
# MENÚ TEXTO BÁSICO (Fallback)
# ------------------------------------------------------------------------------
menu_texto() {
    while true; do
        clear
        echo "================================================================="
        echo "         MENÚ PRINCIPAL - PERFILES DE AUDIO & SHELL              "
        echo "================================================================="
        echo " 1) SOF Interno                  - Out Laptop + In Laptop"
        echo " 2) SOF Filtro                   - Out Laptop + In Laptop (Filtro)"
        echo " 3) JBL Directo                  - Out JBL + In JBL Mic"
        echo " 4) JBL Filtro                   - Out JBL + In JBL Mic (Filtro)"
        echo " 5) JBL Loopback Mic-JBL         - Monitoreo Mic JBL en auriculares"
        echo " 6) JBL Filtro-Loopback Mic-JBL  - Monitoreo Mic JBL con Filtro"
        echo " 7) JBL Loopback Mic-Laptop      - Monitoreo Mic Laptop en auriculares"
        echo " 8) JBL Filtro-Loopback Mic-Lap  - Monitoreo Mic Laptop con Filtro"
        echo " 9) QA Test Suite                - Ejecutar suite de pruebas"
        echo " 0) Salir"
        echo "================================================================="
        read -r -p "Selecciona una opción [0-9]: " OPCION

        case "$OPCION" in
            0|q|Q) break ;;
            [1-9])
                procesar_opcion "$OPCION"
                echo ""
                read -r -p "Presiona [Enter] para continuar..."
                ;;
            *)
                echo "Opción inválida."
                sleep 1
                ;;
        esac
    done
}

procesar_opcion() {
    local opt="$1"
    case "$opt" in
        1)
            ejecutar_perfil "OUT=sof-snd-dsp-IN=sof-snd-dsp.sh" "SOF Interno"
            ;;
        2)
            ejecutar_perfil "OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh" "SOF Filtro"
            ;;
        3)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh" "JBL Directo"
            ;;
        4)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh" "JBL Filtro"
            ;;
        5)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh" "JBL Loopback Mic-JBL"
            ;;
        6)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh" "JBL Filtro-Loopback Mic-JBL"
            ;;
        7)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh" "JBL Loopback Mic-Laptop"
            ;;
        8)
            ejecutar_perfil "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh" "JBL Filtro-Loopback Mic-Laptop"
            ;;
        9)
            echo ">>> Iniciando QA Test Plan..."
            bash "${DIR_BASE}/qa_audio_test_plan.sh"
            ;;
        *)
            echo "Opción no reconocida: $opt"
            ;;
    esac
}

# Lanzador automático según el entorno disponible (YAD gráfico > Dialog TTY > Texto)
if has_gui; then
    menu_yad
elif has_dialog; then
    menu_dialog
else
    menu_texto
fi
