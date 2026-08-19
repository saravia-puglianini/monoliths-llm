#!/bin/bash
# Wrapper de compatibilidad hacia atrás para JBL-FILTER-Quantum350-wireless.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh" "$@"
