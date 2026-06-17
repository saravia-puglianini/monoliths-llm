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

# ------------------------------------------------------------------------------
# 2. Usar el nombre extraído:
#    - minúsculas
#    - sin símbolos raros
#    - espacios -> _
#    - concatenar .en.pdf
#    - copiar al portapapeles con xclip
# ------------------------------------------------------------------------------

FILENAME=$(
    echo "$TEXT" | \
    iconv -f utf8 -t ascii//TRANSLIT 2>/dev/null | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9 ]//g' | \
    xargs | \
    tr ' ' '_' | \
    cut -c1-120
)

PDF_NAME="${FILENAME}.en.pdf"

echo -n "$PDF_NAME" | xclip -selection clipboard

echo "Copiado al portapapeles:"
echo "$PDF_NAME"