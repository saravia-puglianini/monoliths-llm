#!/bin/bash

# Exit on error
set -e

# Support both explicit argument passing and symlink-name auto-detection
ACTION="$1"
TARGET_LANG="$2"

if [ -z "$ACTION" ] || [ -z "$TARGET_LANG" ]; then
    INVOCATION=$(basename "$0")
    if [[ "$INVOCATION" =~ ocr_(vociferar|traducir)_(es|en|de)_(HP|ASUS) ]]; then
        ACTION="${BASH_REMATCH[1]}"
        TARGET_LANG="${BASH_REMATCH[2]}"
    fi
fi

# Validate inputs
if [ -z "$ACTION" ] || [ -z "$TARGET_LANG" ]; then
    echo "Usage: $0 <vociferar|traducir> <es|en|de>" >&2
    echo "Or invoke via a symlink named ocr_<vociferar|traducir>_<es|en|de>_<HP|ASUS>" >&2
    exit 1
fi

# Define languages and OCR modes
case "$TARGET_LANG" in
    es)
        OCR_LANG_OFFLINE="deu"
        OCR_LANG_ONLINE="deu+eng+spa"
        PIPER_MODEL="es_MX-claude-high.onnx"
        ;;
    en)
        OCR_LANG_OFFLINE="spa"
        OCR_LANG_ONLINE="spa+deu+eng"
        PIPER_MODEL="en_US-ryan-high.onnx"
        ;;
    de)
        OCR_LANG_OFFLINE="spa"
        OCR_LANG_ONLINE="spa+eng+deu"
        PIPER_MODEL="de_DE-thorsten-high.onnx"
        ;;
    *)
        echo "Unsupported target language: $TARGET_LANG" >&2
        exit 1
        ;;
esac

# 1. Check internet to set OCR lang and translation mechanism
if ping -c 1 gnu.org >/dev/null 2>&1; then
    ONLINE=1
    OCR_LANG="$OCR_LANG_ONLINE"
else
    ONLINE=0
    # For offline "vociferar", the text language is the target language itself
    if [ "$ACTION" = "vociferar" ]; then
        case "$TARGET_LANG" in
            es) OCR_LANG="spa" ;;
            en) OCR_LANG="eng" ;;
            de) OCR_LANG="deu" ;;
        esac
    else
        OCR_LANG="$OCR_LANG_OFFLINE"
    fi
fi

# 2. CAPTURA AND OCR
# We take a screenshot of a selected area and run OCR on it
RAW_TEXT=$(scrot -s -o - 2>/dev/null | tesseract stdin stdout -l "$OCR_LANG" --oem 1 --psm 6 2>/dev/null)

# Clean up raw text (remove linebreaks, hyphenations, excess spaces)
CLEAN_TEXT=$(printf '%s\n' "$RAW_TEXT" | tr '\n' ' ' | tr -s ' ' | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/- //g')

# If no text was captured, exit quietly
if [ -z "$CLEAN_TEXT" ]; then
    exit 0
fi

# 3. TRANSLATION (if action is 'traducir')
if [ "$ACTION" = "traducir" ]; then
    if [ "$ONLINE" -eq 1 ]; then
        case "$TARGET_LANG" in
            es)
                TRANS_TEXT=$($HOME/googletrans/dist/googletrans-es "$CLEAN_TEXT" 2>/dev/null)
                ;;
            en)
                TRANS_TEXT=$($HOME/googletrans/dist/googletrans-en "$CLEAN_TEXT" 2>/dev/null)
                ;;
            de)
                TRANS_TEXT=$($HOME/googletrans/dist/googletrans-de "$CLEAN_TEXT" 2>/dev/null)
                ;;
        esac
    else
        # Offline via apertium
        case "$TARGET_LANG" in
            es)
                TRANS_TEXT=$(printf '%s\n' "$CLEAN_TEXT" | apertium deu-eng 2>/dev/null | apertium eng-spa 2>/dev/null | tr -d '*' | tr -d '#')
                ;;
            en)
                TRANS_TEXT=$(printf '%s\n' "$CLEAN_TEXT" | apertium spa-eng 2>/dev/null | tr -d '*' | tr -d '#')
                ;;
            de)
                TRANS_TEXT=$(printf '%s\n' "$CLEAN_TEXT" | apertium spa-eng 2>/dev/null | apertium eng-deu 2>/dev/null | tr -d '*' | tr -d '#')
                ;;
        esac
    fi
    # If translation failed or returned empty, fallback to clean text
    if [ -z "$TRANS_TEXT" ]; then
        TEXT_TO_SPEAK="$CLEAN_TEXT"
    else
        TEXT_TO_SPEAK="$TRANS_TEXT"
    fi
else
    TEXT_TO_SPEAK="$CLEAN_TEXT"
fi

# 4. SEQUENTIAL AUDIO GENERATION AND PLAYBACK
(
    flock -x 99
    
    TMPWAV=$(mktemp /tmp/tts.XXXXXX.wav)
    
    # Generate speech
    printf '%s\n' "$TEXT_TO_SPEAK" | $HOME/piper/piper --model $HOME/piper/$PIPER_MODEL --output_file "$TMPWAV" >/dev/null 2>&1
    
    # Play speech
    if [ -s "$TMPWAV" ]; then
        mpv --no-video --quiet "$TMPWAV" >/dev/null 2>&1
    fi
    
    # Clean up
    rm -f "$TMPWAV"
) 99>/tmp/ocr_speech_queue.lock

exit 0
