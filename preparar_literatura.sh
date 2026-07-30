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
sed -i 's/\![[:space:]]/\.\n/g' "$1"
sleep 0.1
sed -i 's/\?[[:space:]]/\.\n/g' "$1"
sleep 0.1
sed -i 's/\;[[:space:]]/\.\n/g' "$1"
sleep 0.1
sed -i 's/\:[[:space:]]/\.\n/g' "$1"
sleep 0.1
sed -i 's/\,[[:space:]]/\,\n/g' "$1"
sleep 0.1
sed -i 's/^[[:space:]]*//' "$1"
sleep 0.1
sed -i 's/ :/:/g' "$1"
sleep 0.1
echo listo
