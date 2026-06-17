#!/bin/dash

# Script: a-llm-yad.sh
# Propósito: Interfaz gráfica (YAD) para el menú de my.shell.sh
# Autor: Antigravity
# Requisitos: yad, dash, awk

SOURCE_SCRIPT="$HOME/monoliths-hm/my.shell.sh"

# Verificar existencia de dependencias
if ! command -v yad >/dev/null 2>&1; then
    printf "Error: 'yad' no está instalado en el sistema.\n" >&2
    exit 1
fi

if [ ! -f "$SOURCE_SCRIPT" ]; then
    yad --error --text="No se encontró el script origen:\n$SOURCE_SCRIPT" --title="Error de Archivo"
    exit 1
fi

# Extraer las opciones dinámicamente de my.shell.sh
# Ejecutamos el script con entrada vacía para capturar su salida de menú
# y luego procesamos con awk para separar ID, Nombre y Descripción.
YAD_DATA=$(dash "$SOURCE_SCRIPT" <<EOF 2>/dev/null | awk '
/^[0-9]+\)/ {
    # Dividir la línea en la parte del comando y la descripción
    # El formato esperado es: N) Comando - Descripción
    sep_pos = index($0, " - ")
    if (sep_pos > 0) {
        cmd_part = substr($0, 1, sep_pos - 1)
        desc = substr($0, sep_pos + 3)
    } else {
        cmd_part = $0
        desc = ""
    }

    # Extraer ID y Nombre del cmd_part (ej: "1) Mi_Comando")
    id_pos = index(cmd_part, ") ")
    if (id_pos > 0) {
        id = substr(cmd_part, 1, id_pos - 1)
        name = substr(cmd_part, id_pos + 2)
    } else {
        id = "?"
        name = cmd_part
    }

    # Limpiar espacios
    gsub(/^[ \t]+|[ \t]+$/, "", id)
    gsub(/^[ \t]+|[ \t]+$/, "", name)
    gsub(/^[ \t]+|[ \t]+$/, "", desc)

    # Si no hay descripción, usar el nombre
    if (desc == "") desc = name

    # Imprimir para que yad lo lea (un campo por línea)
    print id
    print name
    print desc
}
'
EOF
)

# Mostrar el menú YAD
# Redirigimos stderr a /dev/null para ocultar avisos de temas GTK
SELECTED=$(printf "%s\n" "$YAD_DATA" | yad --list \
    --title="Panel de Control Monoliths" \
    --window-icon="system-run" \
    --text="Seleccione una acción y presione Ejecutar:" \
    --width=850 --height=650 --center \
    --column="ID":NUM \
    --column="Acción                         ":TEXT \
    --column="Descripción":TEXT \
    --button="Ejecutar!system-run:0" \
    --print-column=1 --hide-column=1 --separator="" \
    --search-column=2 \
    --ellipsize=END 2>/dev/null)

# Verificar si se seleccionó algo (código de salida 0 de yad)
RET=$?
if [ $RET -ne 0 ] || [ -z "$SELECTED" ]; then
    exit 0
fi

# Ejecutar la opción seleccionada
# CAMBIO CRÍTICO: En lugar de pasar el parámetro (que falla en my.shell.sh por errores de comillas),
# simulamos la entrada de teclado en el modo interactivo del script original.
# Esto evita que my.shell.sh intente grepear su propio código y falle con las opciones 75-79.
echo "$SELECTED" | dash "$SOURCE_SCRIPT" >/dev/null 2>&1 &

# Notificación opcional si notify-send está disponible
if command -v notify-send >/dev/null 2>&1; then
    notify-send "Monoliths" "Iniciando: $SELECTED" --icon=system-run --expire-time=2000 >/dev/null 2>&1
fi
