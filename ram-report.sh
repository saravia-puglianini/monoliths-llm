#!/bin/bash

# Este script reporta el consumo de memoria RAM (RSS) agrupado por programa en MB.
# Se ordenan de mayor a menor consumo y se muestran los 25 programas principales.

echo -e "Memoria (MB)\tPrograma"
echo -e "------------\t--------"

ps -eo rss,comm --no-headers | awk '{
    # El comando "ps" devuelve el RSS en Kilobytes, lo acumulamos por nombre de programa
    ram[$2] += $1
}
END {
    for (prog in ram) {
        mb = ram[prog] / 1024;
        # Imprimimos con 2 decimales y el nombre del programa
        printf "%.2f\t%s\n", mb, prog;
    }
}' | sort -rn | head -n 25 | awk -F'\t' '{printf "%-12s\t%s\n", $1 " MB", $2}'
