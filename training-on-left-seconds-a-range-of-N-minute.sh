#!/bin/dash

# validar parámetro
if [ -z "$1" ]; then
    printf 'uso: %s N\n' "$0" >&2
    exit 1
fi

range=$1

# segundos actuales
sec=$(date '+%S')
sec=${sec#0}
[ -z "$sec" ] && sec=0
time_left=$((60 - sec))

# hora y minuto actuales
hour=$(date '+%H')
min=$(date '+%M')

hour=${hour#0}
min=${min#0}
[ -z "$hour" ] && hour=0
[ -z "$min" ] && min=0

# start = próximo minuto
min=$((min + 1))
if [ "$min" -eq 60 ]; then
    min=0
    hour=$((hour + 1))
    [ "$hour" -eq 24 ] && hour=0
fi

start_hour=$hour
start_min=$min
start=$(printf '%02d:%02d' "$start_hour" "$start_min")

# end = start + N minutos
i=0
while [ "$i" -lt "$range" ]; do
    min=$((min + 1))
    if [ "$min" -eq 60 ]; then
        min=0
        hour=$((hour + 1))
        [ "$hour" -eq 24 ] && hour=0
    fi
    i=$((i + 1))
done

end=$(printf '%02d:%02d' "$hour" "$min")

# # debug visible
# printf 'time_left=%s\nstart=%s\nend=%s\n' \
#        "$time_left" \
#        "$start" \
#        "$end"

# ejecutar
dash $HOME/monoliths-llm/second-counter.sh "$time_left"
if [ ! -f /tmp/.stop ]; then
    (xtimemon -S "$start" -E "$end"; paplay /usr/share/sounds/freedesktop/stereo/complete.oga) &
fi
