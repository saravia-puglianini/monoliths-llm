#!/bin/bash
# ==============================================================================
# Script: /home/user/monoliths-llm/qa_audio_test_plan.sh
# Plan de Pruebas QA Interactivo con Diálogos YAD para Validación Auditiva y Técnica
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="/tmp/qa_audio_report.txt"
QA_LOG="/tmp/qa_audio_execution.log"

echo "=== Inicio Suite QA Audio ($(date '+%Y-%m-%d %H:%M:%S')) ===" > "$QA_LOG"
echo "========================================================" > "$REPORT_FILE"
echo "         REPORTE DE RESULTADOS DE PRUEBAS QA AUDIO       " >> "$REPORT_FILE"
echo "         Fecha: $(date '+%Y-%m-%d %H:%M:%S')             " >> "$REPORT_FILE"
echo "========================================================" >> "$REPORT_FILE"

log_qa() {
    local msg="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$QA_LOG"
}

# Generar tono de prueba sintético por 1.2 segundos sin depender de archivos wav externos
play_test_tone() {
    local target_device="$1"
    local freq="${2:-440}"
    log_qa "Generando tono de prueba ($freq Hz) en $target_device..."
    gst-launch-1.0 -q audiotestsrc wave=sine freq="$freq" num-buffers=60 ! audio/x-raw, rate=48000, channels=2 ! alsasink device="$target_device" sync=false 2>/dev/null || \
    speaker-test -D "$target_device" -c 2 -t sine -f "$freq" -l 1 >/dev/null 2>&1 || true
}

# Diálogo de confirmación interactiva con el usuario (Sí / No)
ask_user_confirmation() {
    local title="$1"
    local header="$2"
    local details="$3"
    local question="$4"
    local icon="${5:-dialog-question}"

    yad --title="QA Audio: $title" \
        --image="$icon" \
        --window-icon="audio-volume-high" \
        --text="<big><b>$header</b></big>\n\n$details\n\n<b>$question</b>" \
        --button="✘ No / Falló:1" \
        --button="✔ Sí / Correcto:0" \
        --width=620 \
        --center \
        --borders=15 2>/dev/null
    return $?
}

# Diálogo informativo con botón de continuar
show_info() {
    local title="$1"
    local msg="$2"
    yad --title="QA Audio: $title" \
        --image="dialog-information" \
        --text="$msg" \
        --button="Iniciar Prueba:0" \
        --width=550 \
        --center \
        --borders=15 2>/dev/null
}

# Grabar 3 segundos y reproducir
record_and_playback_test() {
    local sink_device="$1"
    local tmp_wav="/tmp/qa_rec_temp.wav"
    rm -f "$tmp_wav"

    yad --title="Grabación de Prueba" \
        --image="audio-input-microphone" \
        --text="<big><b>Preparando Grabación de 3 Segundos</b></big>\n\nHaz clic en <b>Grabar</b> y habla por el micrófono activo..." \
        --button="🎙️ Comenzar Grabación:0" \
        --center --width=500 2>/dev/null

    (
        arecord -d 3 -f S16_LE -r 48000 -c 1 "$tmp_wav" 2>/dev/null || \
        arecord -d 3 "$tmp_wav" 2>/dev/null
    ) &
    local rec_pid=$!

    yad --progress \
        --title="Grabando..." \
        --text="Grabando audio (3 segundos)... ¡Habla ahora!" \
        --pulsate \
        --auto-close \
        --auto-kill \
        --width=450 --center 2>/dev/null
    wait $rec_pid 2>/dev/null

    if [ -f "$tmp_wav" ] && [ -s "$tmp_wav" ]; then
        log_qa "Reproduciendo muestra grabada en $sink_device..."
        aplay -D "$sink_device" "$tmp_wav" >/dev/null 2>&1 &
        local play_pid=$!
        yad --progress \
            --title="Reproduciendo..." \
            --text="Reproduciendo la grabación en tu dispositivo..." \
            --pulsate \
            --auto-close \
            --width=450 --center 2>/dev/null
        wait $play_pid 2>/dev/null
        rm -f "$tmp_wav"
        return 0
    else
        log_qa "ERROR: No se pudo capturar la muestra de audio."
        return 1
    fi
}

# ==============================================================================
# DEFINICIÓN DE PRUEBAS INDIVIDUALES
# ==============================================================================

# Prueba 1: OUT=sof-snd-dsp-IN=sof-snd-dsp.sh
test_case_1() {
    local name="1. OUT=sof-snd-dsp / IN=sof-snd-dsp"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=sof-snd-dsp-IN=sof-snd-dsp.sh" >> "$QA_LOG" 2>&1

    # Verificación técnica
    local auto_ok="OK"
    if ! lsmod | grep -q "snd_sof_pci_intel_tgl"; then
        auto_ok="FALLO (módulo SOF no cargado)"
    fi
    if lsmod | grep -q "snd_aloop"; then
        auto_ok="FALLO (snd-aloop no debería estar cargado)"
    fi

    # Verificación auditiva
    play_test_tone "plug:dmix_sof" 520
    record_and_playback_test "plug:dmix_sof"

    if ask_user_confirmation "$name" \
        "Validación de Audio Interno Laptop (SOF)" \
        "• <b>Verificación Técnica:</b> Drivers SOF cargados: <i>$auto_ok</i>\n• <b>Prueba Auditiva:</b> Se reprodujo un tono a 520Hz y tu grabación por los parlantes internos." \
        "¿Escuchaste el tono y tu voz grabada claramente por los ALTAVOCES DE LA LAPTOP?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 2: OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh
test_case_2() {
    local name="2. OUT=sof-snd-dsp / IN=sof-snd-dsp-FILTER"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    [ ! -f /tmp/jbl_pipeline ] && auto_ok="FALLO (pipeline de filtro no generado)"

    play_test_tone "plug:dmix_sof" 520

    if ask_user_confirmation "$name" \
        "Validación SOF con Micrófono Filtrado (DSP)" \
        "• <b>Verificación Técnica:</b> Pipeline DSP activo: <i>$auto_ok</i>\n• <b>Configuración:</b> Micrófono interno procesado con filtro High-Pass y Expansor de ruido." \
        "¿Confirmas que el tono sonó en la laptop y el perfil filtrado está operativo?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 3: OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh
test_case_3() {
    local name="3. OUT=jbl-usb-wireless / IN=jbl-usb-wireless"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    if ! lsmod | grep -q "snd_usb_audio"; then
        auto_ok="FALLO (snd-usb-audio no cargado)"
    fi
    if lsmod | grep -q "snd_sof_pci_intel_tgl"; then
        auto_ok="FALLO (módulos SOF no fueron apagados)"
    fi

    play_test_tone "plug:dmix_speaker" 440
    record_and_playback_test "plug:dmix_speaker"

    if ask_user_confirmation "$name" \
        "Validación de Audio Inalámbrico JBL Directo" \
        "• <b>Verificación Técnica:</b> Driver USB activo, SOF apagado: <i>$auto_ok</i>\n• <b>Estado:</b> Módulos innecesarios descargados." \
        "¿Escuchaste el tono (440Hz) y tu voz en los AURICULARES JBL (y nada por la laptop)?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 4: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh
test_case_4() {
    local name="4. OUT=jbl-usb-wireless / IN=jbl-usb-wireless-FILTER"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    [ ! -f /tmp/jbl_pipeline ] && auto_ok="FALLO (pipeline de filtro no generado)"

    play_test_tone "plug:dmix_speaker" 440

    if ask_user_confirmation "$name" \
        "Validación JBL con Filtro DSP Anti-Ruido" \
        "• <b>Verificación Técnica:</b> Pipeline de filtro en /tmp/jbl_pipeline: <i>$auto_ok</i>\n• <b>Configuración:</b> Captura JBL con supresión de ruido activa." \
        "¿Confirmas que el tono sonó en los auriculares JBL?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 5: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh
test_case_5() {
    local name="5. OUT=jbl-usb-wireless / IN=jbl / LOOPBACK=jbl"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    if ! pgrep -f "gst-launch-1.0" >/dev/null 2>&1; then
        auto_ok="FALLO (proceso gst-launch-1.0 no está corriendo)"
    fi

    if ask_user_confirmation "$name" \
        "Prueba de Loopback en Tiempo Real (Mic JBL ➔ JBL)" \
        "• <b>Verificación Técnica:</b> Proceso loopback activo: <i>$auto_ok</i>\n• <b>Instrucción:</b> Habla normalmente por el micrófono de tus auriculares JBL.\n• <b>Latencia esperada:</b> Ultra-baja (~0.5ms, sin eco molesto)." \
        "¿Te escuchas a ti mismo en tiempo real a través de los audífonos JBL?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 6: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh
test_case_6() {
    local name="6. OUT=jbl-usb-wireless / IN=jbl / FILTER-LOOPBACK=jbl"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    if ! pgrep -f "gst-launch-1.0" >/dev/null 2>&1; then
        auto_ok="FALLO (proceso gst-launch-1.0 no está corriendo)"
    fi

    if ask_user_confirmation "$name" \
        "Prueba de Loopback con Filtro Anti-Ruido (Mic JBL ➔ JBL)" \
        "• <b>Verificación Técnica:</b> Pipeline con expansor activo: <i>$auto_ok</i>\n• <b>Instrucción:</b> Habla por el micrófono JBL y haz ruido de fondo suave (tecleo, respiración).\n• <b>Efecto esperado:</b> Tu voz se escucha clara y el ruido de fondo suave se corta/atenúa." \
        "¿Notas que tu voz se escucha y el filtro de ruido actúa correctamente?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 7: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh
test_case_7() {
    local name="7. OUT=jbl / IN=jbl / LOOPBACK(Mic Laptop ➔ JBL)"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    if ! pgrep -f "gst-launch-1.0" >/dev/null 2>&1; then
        auto_ok="FALLO (proceso gst-launch-1.0 no está corriendo)"
    fi
    if ! lsmod | grep -q "snd_sof_pci_intel_tgl"; then
        auto_ok="FALLO (módulos SOF no fueron encendidos para la captura)"
    fi

    if ask_user_confirmation "$name" \
        "Prueba de Monitoreo Micrófono Laptop ➔ Auriculares JBL" \
        "• <b>Verificación Técnica:</b> JBL + SOF activos: <i>$auto_ok</i>\n• <b>Instrucción:</b> Ponte los audífonos JBL y habla o da golpecitos suaves cerca del teclado/pantalla de la laptop." \
        "¿Escuchas el micrófono de la LAPTOP directamente en tus audífonos JBL en tiempo real?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# Prueba 8: OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh
test_case_8() {
    local name="8. OUT=jbl / IN=jbl / FILTER-LOOPBACK(Mic Laptop ➔ JBL)"
    log_qa "Iniciando $name..."
    "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh" >> "$QA_LOG" 2>&1

    local auto_ok="OK"
    if ! pgrep -f "gst-launch-1.0" >/dev/null 2>&1; then
        auto_ok="FALLO (proceso gst-launch-1.0 no está corriendo)"
    fi

    if ask_user_confirmation "$name" \
        "Prueba de Monitoreo Micrófono Laptop con Filtro Anti-Ruido ➔ JBL" \
        "• <b>Verificación Técnica:</b> Filtro DSP + Loopback activo: <i>$auto_ok</i>\n• <b>Instrucción:</b> Habla hacia el micrófono de la Laptop con los audífonos JBL puestos." \
        "¿Escuchas tu voz proveniente del micrófono de la laptop procesada y con reducción de ruido en tus JBL?"; then
        echo "[$name]: PASÓ (Confirmado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 0
    else
        echo "[$name]: FALLÓ (Rechazado por usuario) [Técnico: $auto_ok]" >> "$REPORT_FILE"
        return 1
    fi
}

# ==============================================================================
# MENU PRINCIPAL Y CONTROL DE FLUJO
# ==============================================================================

run_all_tests() {
    test_case_1
    test_case_2
    test_case_3
    test_case_4
    test_case_5
    test_case_6
    test_case_7
    test_case_8
}

show_summary() {
    local report_content
    report_content=$(cat "$REPORT_FILE" 2>/dev/null)

    yad --text-info \
        --title="Reporte Final QA de Audio" \
        --image="dialog-information" \
        --width=720 \
        --height=450 \
        --button="Guardar y Cerrar:0" \
        --editable=false \
        <<< "$report_content" 2>/dev/null
}

main_menu() {
    while true; do
        ACTION=$(yad --list \
            --title="Plan de Pruebas QA de Audio" \
            --image="audio-card" \
            --text="<b>Selecciona una opción del Plan de Pruebas QA:</b>\nValida técnica y auditivamente cada uno de los 8 perfiles de audio." \
            --column="Opción" --column="Descripción" \
            --width=750 --height=380 \
            --center \
            "ALL" "▶ Ejecutar TODAS las 8 pruebas secuencialmente" \
            "1" "Test 1: OUT=sof-snd-dsp / IN=sof-snd-dsp" \
            "2" "Test 2: OUT=sof-snd-dsp / IN=sof-snd-dsp-FILTER" \
            "3" "Test 3: OUT=jbl-usb-wireless / IN=jbl-usb-wireless" \
            "4" "Test 4: OUT=jbl-usb-wireless / IN=jbl-usb-wireless-FILTER" \
            "5" "Test 5: OUT=jbl / IN=jbl / LOOPBACK=jbl" \
            "6" "Test 6: OUT=jbl / IN=jbl / FILTER-LOOPBACK=jbl" \
            "7" "Test 7: OUT=jbl / IN=jbl / LOOPBACK (Mic Laptop ➔ JBL)" \
            "8" "Test 8: OUT=jbl / IN=jbl / FILTER-LOOPBACK (Mic Laptop ➔ JBL)" \
            "REPORT" "📊 Ver Reporte de Pruebas Actual" \
            --button="Salir:1" --button="Ejecutar Selección:0" 2>/dev/null)

        local exit_code=$?
        [ $exit_code -ne 0 ] && break

        CHOICE=$(echo "$ACTION" | cut -d'|' -f1)

        case "$CHOICE" in
            "ALL")
                run_all_tests
                show_summary
                ;;
            "1") test_case_1 ;;
            "2") test_case_2 ;;
            "3") test_case_3 ;;
            "4") test_case_4 ;;
            "5") test_case_5 ;;
            "6") test_case_6 ;;
            "7") test_case_7 ;;
            "8") test_case_8 ;;
            "REPORT") show_summary ;;
            *) break ;;
        esac
    done
}

# Inicio
show_info "Bienvenido al Plan QA de Audio" \
"<big><b>Plan de Pruebas QA de Audio Modular</b></big>\n\nEste asistente te permitirá validar cada una de las funcionalidades de audio:\n\n• <b>Validación Automática:</b> Comprobación de carga/descarga de módulos y procesos.\n• <b>Validación Auditiva (Tu oído):</b> Generación de tonos de prueba, grabación y loopback en tiempo real.\n• <b>Confirmación YAD:</b> Podrás marcar <b>Sí</b> o <b>No</b> en cada pantalla según lo que escuches.\n\nAl finalizar se generará un reporte en: <i>$REPORT_FILE</i>"

main_menu
