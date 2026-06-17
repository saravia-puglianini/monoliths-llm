#!/usr/bin/env bash

# Directorio base
BASE_DIR="$HOME/monoliths-llm"

echo "[*] Iniciando servicio de lectura de libros..."
python3 "$BASE_DIR/python_book_reader_service.py" &
PY_PID=$!

echo "[*] Iniciando selector de voz (YAD)..."
bash "$BASE_DIR/script-literatura-yad.sh"

# Cuando el selector de voz se cierra (por el usuario o por el monitor)
# nos aseguramos de que el servicio de python también termine.
if kill -0 $PY_PID 2>/dev/null; then
    echo "[*] Cerrando servicio de lectura..."
    kill $PY_PID 2>/dev/null
fi

echo "[*] Sistema detenido."
