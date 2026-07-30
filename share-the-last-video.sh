#!/bin/dash

VIDEO_DIR="$HOME"
DATE_TAG="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="$HOME/001.app-demo-share-$DATE_TAG.mp4"

latest_video=$(ls -t "$VIDEO_DIR"/simplescreenrecorder-*.mkv 2>/dev/null | head -1)

if [ -n "$latest_video" ]; then
    ffmpeg -i "$latest_video" -c copy -- "$OUT_FILE"
    echo "Saved: $OUT_FILE"
else
    echo 'No se encontraron archivos simplescreenrecorder-*.mkv'
fi
