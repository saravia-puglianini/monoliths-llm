#!/bin/dash

# Limpiar archivos temporales de la sesión
i=1
while [ $i -le 7 ]; do
    [ -f "$HOME/.N_session_$i" ] && rm "$HOME/.N_session_$i"
    i=$((i + 1))
done

while true; do
    # Mostrar menú con yad - pasar cada opción como argumento separado
    opcion=$(yad --title='Selecciona una opcion' \
        --list \
        --column='ID' --column='Accion' \
        1 "Chicle$([ -f "$HOME/.N_session_1' ] && echo ' ✔ listo')' \
        2 "Mandíbula$([ -f "$HOME/.N_session_2' ] && echo ' ✔ listo')' \
        3 "Labios$([ -f "$HOME/.N_session_3' ] && echo ' ✔ listo')' \
        4 "Lengua$([ -f "$HOME/.N_session_4' ] && echo ' ✔ listo')' \
        5 "Contar hasta quedarse sin aire$([ -f "$HOME/.N_session_5' ] && echo ' ✔ listo')' \
        6 "Pasar la misma frase en tres idiomas$([ -f "$HOME/.N_session_6' ] && echo ' ✔ listo')' \
        7 "Erre$([ -f "$HOME/.N_session_7' ] && echo ' ✔ listo')' \
        --height=300 \
        --width=400 \
        --button='Cancelar':1 \
	--button='OK':0)

    # Cancelar si yad falla o usuario cancela
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Ejecutar la opción si se seleccionó algo
    if [ -n "$opcion" ]; then
        # Extraer el ID (primer caracter antes del |)
        # En dash no tenemos ${opcion%%|*}, así que usamos esto:
        case "$opcion" in
            *'|'*)
                id=$(echo "$opcion" | cut -d'|' -f1)
                ;;
            *)
                id="$opcion"
                ;;
        esac
        
        # Lanzar el script
        dash $HOME/monoliths-llm/simple_second_counter-N.sh 360

        # Marcar como ejecutado en esta sesión
        touch "$HOME/.N_session_$id"
    fi

    sleep 0.1
done