#!/bin/bash

# Find primary active output
OUTPUT=$(xrandr | grep " connected primary" | awk '{print $1}' | head -n 1)

# If no primary is explicitly set, grab the first connected output
if [ -z "$OUTPUT" ]; then
    OUTPUT=$(xrandr | grep " connected" | awk '{print $1}' | head -n 1)
fi

if [ -z "$OUTPUT" ]; then
    echo "Error: No active screen detected." >&2
    exit 1
fi

# Reset to 1x1 if requested
if [ "$1" = "--reset" ] || [ "$1" = "-r" ] || [ "$1" = "reset" ]; then
    echo "Resetting screen $OUTPUT scaling to 1x1..."
    xrandr --output "$OUTPUT" --scale 1x1
    exit 0
fi

# Find current scaling factor (Transform matrix, first item of first line)
# In xrandr --verbose, it looks like:
# Transform:  1.000000 0.000000 0.000000
#             0.000000 1.000000 0.000000
#             0.000000 0.000000 1.000000
CURRENT_SCALE=$(xrandr --verbose | grep -A 10 "^${OUTPUT} connected" | grep "Transform:" | awk '{print $2}')

# Fallback to 1.0 if not found, empty, or 0
if [ -z "$CURRENT_SCALE" ] || [ "$(echo "$CURRENT_SCALE == 0" | bc -l)" -eq 1 ]; then
    CURRENT_SCALE="1.0"
fi

# Double the current scale factor
NEW_SCALE=$(awk -v scale="$CURRENT_SCALE" 'BEGIN {print scale * 2}')

echo "Display: $OUTPUT"
echo "Current Scale: $CURRENT_SCALE"
echo "New Scale: $NEW_SCALE"

# Apply the scale
xrandr --output "$OUTPUT" --scale "${NEW_SCALE}x${NEW_SCALE}"
