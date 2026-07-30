#!/usr/bin/env python3
# FILE: $HOME/transformer/ptransformer.py

"""
Mini QA local usando llama-cpp-python
-------------------------------------

Este script toma un archivo de texto (documento.txt) como base de conocimiento,
busca el fragmento más relevante de manera simple y genera una respuesta razonada
usando un modelo LLaMA pequeño ejecutado en CPU.

Requisitos:
- llama-cpp-python
- Modelo LLaMA o Alpaca cuantizado (.bin) compatible

"""

import sys
from pathlib import Path
from llama_cpp import Llama

# --------------------------
# CONFIGURACIÓN
# --------------------------

MODEL_PATH = "alpaca-1B-q4_0.bin"  # ruta al modelo .bin
DOCUMENT_PATH = "documento.txt"    # archivo con tu manual/documentación
MAX_TOKENS = 200                   # tokens generados por el modelo

# --------------------------
# Cargar documento
# --------------------------
if not Path(DOCUMENT_PATH).exists():
    print(f"No se encontró {DOCUMENT_PATH}. Crea un archivo de texto con tu manual.")
    sys.exit(1)

with open(DOCUMENT_PATH, "r", encoding="utf-8") as f:
    text = f.read()

# Dividir en fragmentos por párrafos
fragments = [p.strip() for p in text.split("\n\n") if p.strip()]

# --------------------------
# Leer pregunta desde terminal
# --------------------------
if len(sys.argv) < 2:
    print("Uso: python3 ptransformer.py 'Tu pregunta aquí'")
    sys.exit(1)

question = " ".join(sys.argv[1:])

# --------------------------
# Función simple de retrieval
# --------------------------
def simple_retrieval(query, fragments):
    """
    Busca el fragmento que comparte más palabras con la pregunta.
    Método muy básico, solo coincidencia de palabras.
    """
    query_words = set(query.lower().split())
    best_frag = ""
    best_score = 0
    for frag in fragments:
        score = len(query_words & set(frag.lower().split()))
        if score > best_score:
            best_score = score
            best_frag = frag
    return best_frag

context = simple_retrieval(question, fragments)

# --------------------------
# Inicializar llama-cpp
# --------------------------
llm = Llama(model_path=MODEL_PATH)

# --------------------------
# Generar respuesta
# --------------------------
prompt = f"Contexto:\n{context}\n\nPregunta: {question}\nRespuesta:"

resp = llm(prompt, max_tokens=MAX_TOKENS)
answer = resp['text'].strip()

print("\nRespuesta generada:")
print(answer)

# HOW TO BUILD
# Run
# 1. `mkdir -p $HOME/transformer`
# 2. `cd $HOME/transformer`
# 3. `virtualenv -p python3 venv`
# 4. `source venv/bin/activate`
# 5. `pacman -S --needed base-devel cmake python-setuptools python-wheel`
# 6. `pip install llama-cpp-python==0.2.24`
# 7. `pip install transformers  --prefer-binary`
# 8. `ln -svf $HOME/literatura/fss.txt ~/transformer/documento.txt`
# 9. `ln -svf $HOME/monoliths-llm/ptransformer.py ~/transformer/`
# 9. `python3 ptransformer.py '¿Qué es el software libre?'`
# # Binary
# pip install pyinstaller
# pyinstaller --onefile ptransformer.py
# Ahora tendrás transformer/dist/ptransformer listo para ejecutar
