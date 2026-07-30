#!/bin/dash

VOZ="$1"
TMP_WAV="$2"
TEXTO_LIMPIO="$3"

# Generar WAV y reproducir
espeak-ng -v"$VOZ" -w "$TMP_WAV" "$TEXTO_LIMPIO"
mpv --quiet --no-terminal "$TMP_WAV"

