#!/bin/dash

if [ -z "$1" ]; then
    echo "Uso: $0 archivo.txt"
    exit 1
fi

ARCHIVO="$1"
ABS_ARCHIVO=$(readlink -f "$ARCHIVO")
echo "$ABS_ARCHIVO" > /tmp/current_reading.txt
SESSION_ID=$(head -c 10 /dev/urandom | tr -dc 'a-f0-9' | head -c 4)

# TEXTO=$(sed 's/-/ /g' "$ARCHIVO")
# TEXTO=$(sed 's/*/ /g' "$ARCHIVO")

# --- Estimar duración según espeak ---
estimar_duracion_espeak() {
    # Si hay argumento lo usamos, si no leemos de stdin
    if [ $# -gt 0 ]; then
        TEXTO_LOCAL="$1"
    else
        TEXTO_LOCAL=$(cat)
    fi

    # velocidad en palabras por minuto
    VELOCIDAD=135
    # pausa entre frases en centésimas de segundo (espeak -g)
    PAUSA_CS=3
    # Convertimos centésimas a segundos
    PAUSA_S=$(echo "scale=2; $PAUSA_CS/100" | bc)

    # Número de palabras
    PALABRAS=$(echo "$TEXTO_LOCAL" | wc -w)

    # Tiempo por palabras en segundos
    TIEMPO_PALABRAS=$(echo "scale=2; $PALABRAS * 60 / $VELOCIDAD" | bc)

    # Número de signos de puntuación que generan pausas
    PAUSAS=$(echo "$TEXTO_LOCAL" | grep -o "[.!?;]" | wc -l)

    # Tiempo total de pausas
    TIEMPO_PAUSAS=$(echo "$PAUSAS * $PAUSA_S" | bc)

    # Duración total aproximada
    DURACION_INT=$(echo "$TIEMPO_PALABRAS + $TIEMPO_PAUSAS" | bc)

    # Añadir un 5% de margen
    DURACION_INT=$(echo "$DURACION_INT * 1.05" | bc)

    # Redondear a entero
    printf "%.0f\n" "$DURACION_INT"
}

# --- Reemplazar números romanos por palabras ---
reemplazar_romanos() {
    # Si hay argumento lo usamos, si no leemos de stdin
    if [ $# -gt 0 ]; then
        echo "$1" | sed -e 's/\bI\b/uno/g' \
			-e 's/\bII\b/dos/g' \
			-e 's/\bIII\b/tres/g' \
			-e 's/\bIV\b/cuatro/g' \
			-e 's/\bV\b/cinco/g' \
			-e 's/\bVI\b/seis/g' \
			-e 's/\bVII\b/siete/g' \
			-e 's/\bVIII\b/ocho/g' \
			-e 's/\bIX\b/nueve/g' \
			-e 's/\bX\b/diez/g' \
			-e 's/\bXX\b/veinte/g' \
			-e 's/\bXXX\b/treinta/g' \
			-e 's/\bXL\b/cuarenta/g' \
			-e 's/\bL\b/cincuenta/g' \
			-e 's/\bLX\b/sesenta/g' \
			-e 's/\bLXX\b/setenta/g' \
			-e 's/\bLXXX\b/ochenta/g' \
			-e 's/\bXC\b/noventa/g' \
			-e 's/\bC\b/cien/g' \
			-e 's/\bD\b/quinientos/g' \
			-e 's/\bM\b/mil/g'
    else
        sed -e 's/\bI\b/uno/g' \
	    -e 's/\bII\b/dos/g' \
	    -e 's/\bIII\b/tres/g' \
	    -e 's/\bIV\b/cuatro/g' \
	    -e 's/\bV\b/cinco/g' \
	    -e 's/\bVI\b/seis/g' \
	    -e 's/\bVII\b/siete/g' \
	    -e 's/\bVIII\b/ocho/g' \
	    -e 's/\bIX\b/nueve/g' \
	    -e 's/\bX\b/diez/g' \
	    -e 's/\bXX\b/veinte/g' \
	    -e 's/\bXXX\b/treinta/g' \
	    -e 's/\bXL\b/cuarenta/g' \
	    -e 's/\bL\b/cincuenta/g' \
	    -e 's/\bLX\b/sesenta/g' \
	    -e 's/\bLXX\b/setenta/g' \
	    -e 's/\bLXXX\b/ochenta/g' \
	    -e 's/\bXC\b/noventa/g' \
	    -e 's/\bC\b/cien/g' \
	    -e 's/\bD\b/quinientos/g' \
	    -e 's/\bM\b/mil/g'
    fi
}

# --- Reemplazar vocales acentuadas solas ---
reemplazar_vocales() {
    # Si hay argumento lo usamos, si no leemos de stdin
    if [ $# -gt 0 ]; then
        TEXTO_LOCAL="$1"
        echo "$TEXTO_LOCAL" | sed -E \
				  -e 's/(^|[[:space:]])á($|[[:space:]])/\1a\2/g' \
				  -e 's/(^|[[:space:]])é($|[[:space:]])/\1e\2/g' \
				  -e 's/(^|[[:space:]])í($|[[:space:]])/\1i\2/g' \
				  -e 's/(^|[[:space:]])ó($|[[:space:]])/\1o\2/g' \
				  -e 's/(^|[[:space:]])ú($|[[:space:]])/\1u\2/g' \
				  -e 's/(^|[[:space:]])ü($|[[:space:]])/\1u\2/g' \
				  -e 's/(^|[[:space:]])Á($|[[:space:]])/\1A\2/g' \
				  -e 's/(^|[[:space:]])É($|[[:space:]])/\1E\2/g' \
				  -e 's/(^|[[:space:]])Í($|[[:space:]])/\1I\2/g' \
				  -e 's/(^|[[:space:]])Ó($|[[:space:]])/\1O\2/g' \
				  -e 's/(^|[[:space:]])Ú($|[[:space:]])/\1U\2/g' \
				  -e 's/(^|[[:space:]])Ü($|[[:space:]])/\1U\2/g'
    else
        sed -E \
	    -e 's/(^|[[:space:]])á($|[[:space:]])/\1a\2/g' \
	    -e 's/(^|[[:space:]])é($|[[:space:]])/\1e\2/g' \
	    -e 's/(^|[[:space:]])í($|[[:space:]])/\1i\2/g' \
	    -e 's/(^|[[:space:]])ó($|[[:space:]])/\1o\2/g' \
	    -e 's/(^|[[:space:]])ú($|[[:space:]])/\1u\2/g' \
	    -e 's/(^|[[:space:]])ü($|[[:space:]])/\1u\2/g' \
	    -e 's/(^|[[:space:]])Á($|[[:space:]])/\1A\2/g' \
	    -e 's/(^|[[:space:]])É($|[[:space:]])/\1E\2/g' \
	    -e 's/(^|[[:space:]])Í($|[[:space:]])/\1I\2/g' \
	    -e 's/(^|[[:space:]])Ó($|[[:space:]])/\1O\2/g' \
	    -e 's/(^|[[:space:]])Ú($|[[:space:]])/\1U\2/g' \
	    -e 's/(^|[[:space:]])Ü($|[[:space:]])/\1U\2/g'
    fi
}

# --- Función para reproducir fragmento ---
reproducir_fragmento() {
    TEXTO_ORIGINAL="$1"
    TEXTO_LIMPIO="$1"
    IDIOMA="$2"
    NUM_FRAG="$3"
    [ -z "$TEXTO_LIMPIO" ] && return

    case "$IDIOMA" in
        es|en|de)
            TEXTO_LIMPIO=$(echo "$TEXTO_LIMPIO" | tr '[:upper:]' '[:lower:]')
            ;;
    esac

    case "$TEXTO_LIMPIO" in
        *[.,]) ;;
        *) TEXTO_LIMPIO="$TEXTO_LIMPIO," ;;
    esac

    NUM_PADDED=$(printf "%010d" "$NUM_FRAG")
    TMP_WAV="${ARCHIVO}_${SESSION_ID}_${NUM_PADDED}.wav"

    case "$IDIOMA" in
        ES|es) VOZ="es-419" ;;
        EN|en) VOZ="en" ;;
        DE|de) VOZ="de" ;;
        *) VOZ="es-419" ;;
    esac

    dash $HOME/monoliths-llm/script-literatura-core.sh "$VOZ" "$TMP_WAV" "$TEXTO_LIMPIO"

}

# --- Función para enviar a dash ---
mostrar_feh_opcional() {
    dash $HOME/monoliths-llm/message_img.sh "$1"
}

# Devuelve la hora actual en formato HH:MM
obtener_hora_actual_S() {
    date "+%H:%M"
}

# Calcula la hora final sumando SEGUNDOS_ASUMAR a la hora actual
obtener_hora_final_E() {
    SEGUNDOS_ASUMAR="$1"
    # `date` en POSIX permite usar -d en Linux; en BSD/macOS podemos usar -v
    if date --version >/dev/null 2>&1; then
        # Linux
        date -d "+$SEGUNDOS_ASUMAR seconds" "+%H:%M"
    else
        # BSD/macOS
        date -v +"$((SEGUNDOS_ASUMAR/3600))H" -v +"$(((SEGUNDOS_ASUMAR%3600)/60))M" "+%H:%M"
    fi
}

execute_xtimemon() {
    killall xtimemon && sleep 0.1
    SEGUNDOS_ASUMAR="$1"
    # ejemplo: xtimemon -S 11:20 -E 11:40 -p left
    # donde 11:20 es la hora actual y se le suma 11:40 en el caso sean 120 segundos
    xtimemon -S "$(obtener_hora_actual_S)" -E "$(obtener_hora_final_E $SEGUNDOS_ASUMAR)" -p left
}

sndiod_task() {
    # Archivo de estado para recordar si el script arrancó sndiod
    STATE_FILE="/tmp/sndiod_toggle_state"

    # Función para verificar si sndiod está corriendo
    is_running() {
	# Usamos ps y grep para POSIX
	ps -e | grep -w "sndiod" >/dev/null 2>&1
    }

    if [ -f "$STATE_FILE" ]; then
	echo "Apagando sndiod..."
	PID=$(cat "$STATE_FILE")
	kill "$PID" 2>/dev/null
	rm -f "$STATE_FILE"
	echo "sndiod apagado."
	killall xtimemon
	echo "pkill xtimemon."
    else
	if is_running; then
            echo "sndiod ya está corriendo. No hacemos nada."
	else
            echo "Encendiendo sndiod..."
            sndiod &
            echo $! > "$STATE_FILE"
            echo "sndiod encendido."
	fi
    fi
}

# --- Función para hablar con pausas ---
hablar_con_pausas() {
    # Evitar que la pantalla se apague durante la lectura
    xset -dpms s off s noblank

    # Tareas de inicio (ej. encender sonido)
    if command -v sndiod | grep sndio > /dev/null; then
	sndiod_task
    fi
    TEXTO="$1"
    DURACION_ESTIMADA="$2"

    # Lanzar temporizador en segundo plano si se especificó duración
    [ -n "$DURACION_ESTIMADA" ] && execute_xtimemon "$DURACION_ESTIMADA" &

    # Normalizar etiquetas de idioma y separar fragmentos
    # Convierte <<EN: en ###en: y >> en ### para facilitar el spliteo
    # Añadimos ### al final de cada línea para procesar el texto línea por línea
    TEXTO_DELIMITADO=$(echo "$TEXTO" | sed 's/<<\([a-zA-Z]\{2\}\):/###\1:/g; s/>>/###/g; s/$/###/g')

    # Obtener el progreso previo si existe (para retomar lectura)
    POS_FILE="${ARCHIVO}.pos"
    START_FROM=0
    
    if [ -f "$ARCHIVO.leido" ]; then
        if [ -f "$POS_FILE" ]; then
            echo ">>> Nota: El archivo estaba marcado como leído, pero se encontró un punto de guardado."
            echo ">>> Continuando lectura y eliminando marca de 'leído'..."
            rm -f "$ARCHIVO.leido"
        else
            echo ">>> Error: El archivo '$(basename "$ARCHIVO")' ya ha sido leído completamente."
            echo ">>> Si deseas leerlo de nuevo, borra el archivo: $ARCHIVO.leido"
            return 0
        fi
    fi

    if [ -f "$POS_FILE" ]; then
        # Leer y limpiar el número
        START_FROM=$(tr -dc '0-9' < "$POS_FILE")
        [ -z "$START_FROM" ] && START_FROM=0
        echo ">>> Retomando lectura de '$(basename "$ARCHIVO")' desde fragmento $((START_FROM + 1))..."
    fi

    # Procesar fragmentos usando awk para clasificar por idioma (por defecto "es")
    echo "$TEXTO_DELIMITADO" | awk '
        BEGIN { RS="###"; ORS="\n"; current_lang="es" }
        {
            # Recortar espacios en blanco
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            if (length($0) == 0) next
            
            # Si el fragmento tiene prefijo de idioma (ej. "en:Hello")
            if ($0 ~ /^[a-zA-Z]{2}:/) {
                idx = index($0, ":")
                lang = substr($0, 1, idx-1)
                content = substr($0, idx+1)
                print lang "|" content
            } else {
                print current_lang "|" $0
            }
        }' | {
        # Usamos el START_FROM calculado arriba (heredado por el subshell)
        CUR_FRAG=0
        
        while IFS="|" read -r IDIOMA CONT; do
            if [ -f /tmp/STOP ]; then
                break
            fi
	    CUR_FRAG=$((CUR_FRAG + 1))
	    
	    # Saltar fragmentos ya leídos
	    if [ "$CUR_FRAG" -le "$START_FROM" ]; then
                continue
	    fi

	    [ -z "$CONT" ] && continue
	    
	    echo "[$IDIOMA] ($CUR_FRAG) $CONT"

	    # Lógica de traducción condicional: solo si el archivo no indica ser español
	    FILE_LC=$(echo "$ARCHIVO" | tr '[:upper:]' '[:lower:]')
	    case "$FILE_LC" in
                *.es.txt|*.esp.txt|*.spa.txt|*.spanish.txt|*.sp.txt|*.es_*.txt|*.es-*.txt|*.esp_*.txt|*.esp-*.txt|*.spa_*.txt|*.spa-*.txt|*.spanish_*.txt|*.spanish-*.txt|*.sp_*.txt|*.sp-*.txt)
                # Ya es español, omitir traducción
                ;;
                *)
		    CONT=$(dash $HOME/monoliths-llm/script-literatura-lang.sh "$CONT")
		    ;;
	    esac

	    # Mostrar en pantalla y reproducir audio
	    mostrar_feh_opcional "$CONT"
	    # ^ Descomentar este para ver el texto en pantalla
	    reproducir_fragmento "$CONT" "$IDIOMA" "$CUR_FRAG"

	    # Pausas reducidas: Piper ya maneja la puntuación.
	    # Solo dejamos un pequeño respiro si es necesario.
	    sleep 0.1
	    
	    # Guardar progreso actual
	    echo "$CUR_FRAG" > "$POS_FILE"
        done
    }

    # Manejar la salida del bucle
    if [ -f /tmp/STOP ]; then
        echo ">>> Lectura interrumpida. Guardando progreso en $POS_FILE"
        killall osd_cat 2>/dev/null
        rm -f /tmp/STOP
    else
        # Finalización natural: marcar como leído y limpiar progreso
        rm -f "$POS_FILE"
        touch "$ARCHIVO.leido"
        echo ">>> Lectura completada: $ARCHIVO"
    fi

    # Tareas de inicio (ej. encender sonido)
    if command -v sndiod | grep sndio > /dev/null; then
	sndiod_task
    fi
    xset +dpms s default
}

# --- Preparar y Ejecutar ---
# Procesamos el texto una sola vez para limpiar caracteres no deseados y vocales
TEXTO_FINAL=$(sed 's/[-*]/ /g' "$ARCHIVO" | reemplazar_vocales)

# Estimamos la duración basándonos en el texto limpio
DURACION=$(echo "$TEXTO_FINAL" | estimar_duracion_espeak)

# Iniciamos el proceso de lectura
hablar_con_pausas "$TEXTO_FINAL" "$DURACION"
