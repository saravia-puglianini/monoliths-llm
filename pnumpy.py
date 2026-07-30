#!/usr/bin/env python3
# FILE: $HOME/numpy/pnumpy.py
import sys
import numpy as np
import re
from collections import Counter

# --------------------------
# Funciones de procesamiento
# --------------------------
def tokenize(text):
    """Convierte un texto en lista de palabras minúsculas."""
    return re.findall(r'\w+', text.lower())

def vectorize(text, vocab):
    """Convierte un texto en vector de conteo de palabras según vocabulario."""
    vec = np.zeros(len(vocab))
    counts = Counter(tokenize(text))
    for i, word in enumerate(vocab):
        vec[i] = counts.get(word, 0)
    return vec

def cosine_sim(a, b):
    """Similitud coseno entre dos vectores."""
    if np.linalg.norm(a) == 0 or np.linalg.norm(b) == 0:
        return 0
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

# --------------------------
# Cargar texto de contexto
# --------------------------
# Puedes cambiar 'documento.txt' por cualquier archivo de texto plano
with open("documento.txt", "r", encoding="utf-8") as f:
    text = f.read()

# Dividir en fragmentos (líneas o párrafos)
fragments = [line.strip() for line in text.split("\n") if line.strip()]

# Construir vocabulario global
vocab = list(set(word for frag in fragments for word in tokenize(frag)))

# Vectorizar fragments
X = np.array([vectorize(frag, vocab) for frag in fragments])

# --------------------------
# Leer pregunta desde terminal
# --------------------------
if len(sys.argv) < 2:
    print("Uso: python3 pnumpy.py 'pregunta aquí'")
    sys.exit(1)

question = " ".join(sys.argv[1:])
q_vec = vectorize(question, vocab)

# --------------------------
# Encontrar el fragmento más relevante
# --------------------------
sims = np.array([cosine_sim(q_vec, x) for x in X])
best_idx = np.argmax(sims)

print("Respuesta más relevante:")
print(fragments[best_idx])

# --------------------------
# HOW TO BUILD
# --------------------------
# 1. `mkdir -p $HOME/numpy`
# 2. `cd $HOME/numpy`
# 3. `virtualenv -p python3 venv`
# 4. `source venv/bin/activate`
# 5. `pip install numpy`
# 6. Guardar tu texto en 'documento.txt'
# 7. `python3 pnumpy.py 'que es el software libre'`
# 8. Para binario (opcional):
#    pip install pyinstaller
#    pyinstaller --onefile numpy.py
#    El ejecutable estará en numpy/dist/numpy
