#!/bin/bash
# Wrapper de compatibilidad hacia atrás para sof-snd-dsp.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/OUT=sof-snd-dsp-IN=sof-snd-dsp.sh" "$@"
