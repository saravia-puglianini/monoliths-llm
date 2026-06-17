#!/bin/dash

message_img() {
    text="$1"

    # 1. Obtener resolución para pantalla completa
    resolution=$(xrandr 2>/dev/null | grep '*' | head -n1 | sed 's/.* \([0-9]\+x[0-9]\+\).*/\1/')
    width=$(echo "$resolution" | cut -dx -f1)
    height=$(echo "$resolution" | cut -dx -f2)
    [ -z "$width" ] && width=1920
    [ -z "$height" ] && height=1080
    
    # 2. Márgenes
    margin=100
    canvas_width=$((width - 2 * margin))
    canvas_height=$((height - 2 * margin))
    
    # 3. Configuración de Fuente (Ruta absoluta para Gentoo)
    font_path="/usr/share/fonts/liberation-fonts/LiberationSans-BoldItalic.ttf"
    [ ! -f "$font_path" ] && font_path="/usr/share/fonts/liberation/LiberationSans-BoldItalic.ttf"
    
    # 4. Construcción dinámica del comando
    if [ -f "$font_path" ]; then
        FONT_ARG="-font $font_path"
    else
        FONT_ARG=""
    fi

    # 5. Ejecución con retrocompatibilidad
    # Usamos fondo negro y texto blanco como indica el README
    run_magick() {
        cmd="$1"
        eval "$cmd -size ${canvas_width}x${canvas_height} \
            -background white \
            -fill black \
            $FONT_ARG \
            -gravity center \
            caption:'$text' \
            -bordercolor white -border $margin \
            '$F'"
    }

    if command -v magick >/dev/null 2>&1; then
        run_magick "magick"
    else
        run_magick "convert"
    fi

    # 6. Mostrar imagen con feh (Llamada asíncrona para no bloquear)
    if command -v feh >/dev/null 2>&1; then
        # Matamos procesos previos de feh con el mismo título para actualizar la pantalla
        pkill -f "feh --title Lectura" 2>/dev/null
        # Mostramos la nueva imagen en segundo plano
        feh --title "Lectura" --no-menus --scale-down --geometry "${width}x${height}+0+0" "$F" &
    fi
    # =======
    #     pgrep feh | xargs kill > /dev/null 2>&1 &
    #     sleep 0.1
    #     feh --borderless "$F" > /dev/null 2>&1 &
    # >>>>>>> 92e42ee589715884bb8d0e168b35f1a83c0ea3b8
}


# Solo mostramos el mensaje si Xournalpp o Google Chrome NO tienen el foco actual.
# Si alguna de estas apps tiene el foco, ocultamos feh para no estorbar.
if true && ! ( xdotool getwindowfocus getwindowname 2>/dev/null | grep -Eiq "Xournal|google chrome" ); then
    # Si no estamos en Xournalpp, procedemos a mostrar la imagen
    tempfile=$(mktemp)
    F="${tempfile}.png"
    [ -f "$F" ] && rm "$F"

    message_img "$1"

    # Limpieza básica
    rm -f "$tempfile"
fi
