#!/bin/bash
# ==============================================================================
# Script de depuración y captura de logs para alt_tab_maximize_emacs_asm
# Ejecútalo en tu otra TTY (por ejemplo: Ctrl+Alt+F2 / Ctrl+Alt+F3) o terminal
# ==============================================================================

set -e

SRC_DIR="/home/user/monoliths-llm"
BIN="$SRC_DIR/alt_tab_maximize_emacs_asm"
DEBUG_BIN="$SRC_DIR/alt_tab_maximize_emacs_asm_dbg"
LOG_DIR="/tmp/asm_wm_debug"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$LOG_DIR"
STDERR_LOG="$LOG_DIR/output_${TIMESTAMP}.log"
STRACE_LOG="$LOG_DIR/strace_${TIMESTAMP}.log"

echo "=== [1/4] Compilando versión con símbolos de depuración (-g) ==="
as -g "$SRC_DIR/alt_tab_maximize_emacs.s" -o "$SRC_DIR/alt_tab_maximize_emacs_dbg.o"
ld "$SRC_DIR/alt_tab_maximize_emacs_dbg.o" -lX11 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o "$DEBUG_BIN"
chmod +x "$DEBUG_BIN"

echo "=== [2/4] Verificando DISPLAY ==="
export DISPLAY="${DISPLAY:-:0}"
echo "Usando DISPLAY=$DISPLAY"

echo "=== [3/4] Deteniendo instancias previas en conflicto si existen ==="
pkill -f "alt_tab_maximize_emacs" || true
sleep 1

echo "=== [4/4] Iniciando ejecución bajo strace con captura completa ==="
echo "Logs de salida directa en: $STDERR_LOG"
echo "Trace completo (señales/crashes) en: $STRACE_LOG"
echo "---------------------------------------------------------------"
echo "Presiona Ctrl+C cuando desees finalizar la captura."
echo "---------------------------------------------------------------"

strace -f -tt -T -e trace=all -s 256 \
    -o "$STRACE_LOG" \
    "$DEBUG_BIN" 2>&1 | tee "$STDERR_LOG"

echo "=== Ejecución finalizada ==="
