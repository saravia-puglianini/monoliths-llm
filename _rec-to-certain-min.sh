#!/bin/sh
# record.sh - Record for specified minutes with SimpleScreenRecorder
# Usage: ./record.sh MINUTES

# Check for argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 MINUTES" >&2
    exit 1
fi

# Validate minutes is a positive integer
case $1 in
    ''|*[!0-9]*)
        echo 'Error: MINUTES must be a positive integer' >&2
        exit 1
        ;;
esac

MINUTES=$1
SECONDS=$((MINUTES * 60))
PID_FILE="/tmp/ssr_$$.pid"
LOG_FILE="${HOME}/.ssr/log-$(date +%Y%m%d_%H%M%S).txt"

echo "Starting recording for $MINUTES minute(s)..."

# Start SSR in background, hidden, with logging
simplescreenrecorder --start-recording --start-hidden --logfile --statsfile >/dev/null 2>&1 &
SSR_PID=$!

# Save PID for cleanup
echo "$SSR_PID" > "$PID_FILE"

# Wait for SSR to initialize (adjust if needed)
sleep 3

echo "Recording started. PID: $SSR_PID"
echo "Recording will stop automatically after $MINUTES minute(s)..."

# Wait for the specified duration
sleep "$SECONDS"

echo 'Stopping recording...'

# Graceful stop - send SIGTERM
if kill -TERM "$SSR_PID" 2>/dev/null; then
    # Give SSR time to finalize the recording
    WAIT_COUNT=0
    MAX_WAIT=10  # Maximum 10 seconds to wait
    
    while kill -0 "$SSR_PID" 2>/dev/null && [ "$WAIT_COUNT" -lt "$MAX_WAIT" ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    # Force kill if still running after waiting
    if kill -0 "$SSR_PID" 2>/dev/null; then
        echo 'SSR not responding, forcing termination...'
        kill -KILL "$SSR_PID" 2>/dev/null
    fi
else
    echo 'SSR process not found or already stopped.'
fi

# Cleanup PID file
rm -f "$PID_FILE"

echo "Recording finished. Log: $LOG_FILE"

sleep 3

latest_video=$(ls -t $HOME/simples* 2>/dev/null | head -1)

if [ -n "$latest_video" ]; then
    ffmpeg -i "$latest_video" -c copy "$HOME/001.app-demo-share-$(date +%M%M%S).${MINUTES}m.mp4"
else
    echo 'No se encontraron archivos simplescreenrecorder-*.mkv'
fi
