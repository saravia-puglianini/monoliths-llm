#!/bin/bash

sleep 0.2

TEXT=$(scrot -s -o - | \
	   tesseract stdin stdout -l eng | \
	   sed -E ':a;N;$!ba;s/-\n//g' | \
	   tr '\n' ' ') || TEXT=$(scrot -s -o - | tesseract stdin stdout -l eng | tr '\n' ' ')

if [ -n "$TEXT" ]; then
    TRAD=$(printf '%s\n' "$TEXT" \
	       | ssh -o LogLevel=ERROR user@192.168.0.164 "apertium eng-spa" \
	       | tr -d '*') || TRAD=$("$HOME/literatura/googletrans-es" "$TEXT")

    printf '%s\n' "$TRAD" | \
	"$HOME/piper/piper" \
	    --model "$HOME/piper/es_MX-claude-high.onnx" \
	    --output-raw | \
	mpv --no-video --cache=no --audio-buffer=0 -
fi