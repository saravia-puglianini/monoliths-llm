#!/bin/dash

VOZ="$1"
TMP_WAV="$2"
TEXTO_LIMPIO="$3"

if [ -z "$TEXTO_LIMPIO" ]; then
    TEXTO_LIMPIO=$(cat)
fi

# Guardar texto en un temporal
echo "$TEXTO_LIMPIO" > /tmp/osd_text.tmp

# Generar el formato en archivo temporal
# Usamos un ancho de 32 para asegurar compatibilidad con cualquier resolución
cat /tmp/osd_text.tmp | fold -s -w 32 > /tmp/osd_format.tmp
# Generamos barras que tengan exactamente el mismo ancho que el texto para alineación perfecta
cat /tmp/osd_format.tmp | sed 's/./|/g' > /tmp/osd_bars.tmp

if false; then
    espeak-ng -v"$VOZ" -w "$TMP_WAV" "$TEXTO_LIMPIO"
    mpv --quiet --no-terminal "$TMP_WAV"
fi

# HIGH QUALITY OR ANOTHER LANGUAGES
if true; then
    #VERSION='de_DE-thorsten-high.onnx'
    #VERSION='en_US-ryan-high.onnx'
    VERSION='es_MX-claude-high.onnx'
    #tmp='es_MX-ald-medium.onnx'

    # Generar usando el nombre de archivo único
    cat /tmp/osd_text.tmp | $HOME/piper/piper --model $HOME/piper/$VERSION --output_file "$TMP_WAV" >/dev/null 2>&1

    if [ "$VERSION" = "de_DE-thorsten-high.onnx" ]; then
        # Limpieza inicial
        killall -9 osd_cat 2>/dev/null
        
        FONT="-*-*-bold-r-*-*-36-*-*-*-*-*-*-*"
        FONT_BARS="-*-*-bold-r-*-*-18-*-*-*-*-*-*-*"
        OFFSET=50
        Grosor=12

        # Renderizado línea a línea para alineación BASE perfecta
        tac /tmp/osd_format.tmp | while IFS= read -r linea; do
            [ -z "$linea" ] && continue
            
            # 1. Resplandor base sólido (Tamaño 36, Grosor 12)
            echo "$linea" | osd_cat --font="$FONT" --colour=white --align=center --pos=bottom --delay=20 --lines=1 --offset=$OFFSET --outline=$Grosor --outlinecolour=white &
            
            # 2. Textura de barras (Tamaño 18 para no desbordar, una cada dos caracteres)
            echo "$linea" | sed 's/../|/g' | osd_cat --font="$FONT_BARS" --colour=white --align=center --pos=bottom --delay=20 --lines=1 --offset=$OFFSET --outline=4 --outlinecolour=white &
            
            # 3. Texto final negro (Añadimos un pequeño retraso para asegurar que quede SIEMPRE ARRIBA)
            sleep 0.1
            echo "$linea" | osd_cat --font="$FONT" --colour=black --align=center --pos=bottom --delay=20 --lines=1 --offset=$OFFSET --outline=$Grosor --outlinecolour=white &
            
            # Incrementar offset para la siguiente línea (65 píxeles para más aire)
            OFFSET=$((OFFSET + 65))
        done
        
        OSD_PID=$!
    fi
    
    mpv --volume=50 --no-terminal --quiet "$TMP_WAV"
    [ -n "$OSD_PID" ] && killall osd_cat 2>/dev/null
fi