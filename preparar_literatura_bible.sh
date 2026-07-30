#!/bin/dash
sed -i 's/^[[:space:]]*//' "$1"
sleep 0.1
sed -i 's/[[:space:]]*$//' "$1"
sleep 0.1
sed -i '/^[[:space:]]*$/d' "$1"
sleep 0.1
sed -i ':a;N;$!ba;s/\n/ /g' "$1"
sleep 0.1
sed -i 's/\.[[:space:]]/\.\n/g' "$1"
sleep 0.1
sed -i 's/\,[[:space:]]/\,\n/g' "$1"
sleep 0.1
sed -i 's/[0-9]+:[0-9]+//g; s/  +/ /g; s/^ //; s/ $//' "$1"
sleep 0.1
sed -i 's/[0-9]//g' "$1"
sleep 0.1
sed -i 's/^[[:space:]]*//' "$1"
sleep 0.1
sed -i 's/ :/:/g' "$1"
sleep 0.1
echo listo
