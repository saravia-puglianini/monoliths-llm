#!/bin/bash

set -e

# -----------------------
# 1. CAPTURA + OCR RÁPIDO
# -----------------------

TEXT=$(
    scrot -s -o - | \
    tesseract stdin stdout -l eng --oem 1 --psm 6 2>/dev/null | \
    tr '\n' ' ' | tr -s ' ' | sed 's/- //g'
)

[ -z "$TEXT" ] && exit 1

# -----------------------
# 2. TRADUCCIÓN (FIX SSH SEGURO)
# -----------------------

TRAD=$(
    printf '%s\n' "$TEXT" | \
    ssh -o BatchMode=yes -o LogLevel=ERROR user@192.168.0.164 \
    "apertium eng-spa" 2>/dev/null | tr -d '*'
)

[ -z "$TRAD" ] && exit 1

# -----------------------
# 3. TTS (SIN RAW, SIN PROBLEMAS DE AUDIO)
# -----------------------

TMPWAV=$(mktemp /tmp/tts.XXXXXX.wav)

echo "$TRAD" | "$HOME/piper/piper" \
    --model "$HOME/piper/es_MX-ald-medium.onnx" \
    --output_file "$TMPWAV"

[ ! -s "$TMPWAV" ] && exit 1

# -----------------------
# 4. REPRODUCCIÓN LIMPIA
# -----------------------

mpv --no-video "$TMPWAV" >/dev/null 2>&1 &

exit 0