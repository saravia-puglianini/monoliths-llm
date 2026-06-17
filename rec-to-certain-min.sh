#!/bin/sh
# record.sh - Record for specified minutes with SimpleScreenRecorder
# Usage: ./record.sh MINUTES

# ---- configuración ----
VIDEO_DIR="$HOME"
DATE_TAG="$(date +%Y%m%d_%H%M%S)"
OUT_PREFIX="$HOME/001.app-demo-share"
PID_FILE="/tmp/ssr_$$.pid"
# -----------------------

# Check for argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 MINUTES" >&2
    exit 1
fi

dash $HOME/monoliths-llm/timer.sh $1 &

# Validate minutes is a positive integer
case $1 in
    ''|*[!0-9]*)
        echo 'Error: MINUTES must be a positive integer' >&2
        exit 1
        ;;
esac

MINUTES=$1
SECONDS=$(($MINUTES * 60))
SECONDS=$(($SECONDS + 1))
PID_FILE="/tmp/ssr_$$.pid"

echo "Starting recording for $MINUTES minute(s)..."

# Wait for SSR to initialize (adjust if needed)
sleep 3

# Start SimpleScreenRecorder
simplescreenrecorder \
    --start-recording \
    --start-hidden &

SSR_PID=$!

echo "$SSR_PID" > "$PID_FILE"
echo "Recording started. PID: $SSR_PID"
echo "Recording will stop automatically after $MINUTES minute(s)..."

WAIT_COUNT=0
while ! echo -n $WAIT_COUNT | grep -q $SECONDS > /dev/null && \
	[ ! -f /tmp/.stop ]; do
    sleep 0.9
    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo "$WAIT_COUNT while"
done

sleep 3

kill -KILL "$SSR_PID" 2>/dev/null

rm -f "$PID_FILE"

echo 'Wating the processor 3 seconds...'

# Give filesystem a moment
sleep 3

# Find latest SSR video
latest_video=$(ls -t "$VIDEO_DIR"/simplescreenrecorder-*.mkv 2>/dev/null | head -1)

if [ -n "$latest_video" ]; then
    OUT_FILE="$OUT_PREFIX-$DATE_TAG-${MINUTES}m.mp4"
    ffmpeg -i "$latest_video" -c copy "$OUT_FILE"
    herbe "Saved: $OUT_FILE"
else
    echo 'No se encontraron archivos simplescreenrecorder-*.mkv'
fi
