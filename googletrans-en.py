# BUILD $HOME/googletrans/dist/googletrans-en
import sys
import os
import contextlib

# Redirigir stderr temporalmente a null
with open(os.devnull, "w") as fnull:
    with contextlib.redirect_stderr(fnull):
        from deep_translator import GoogleTranslator

texto_a_traducir = " ".join(sys.argv[1:])

try:
    with open(os.devnull, "w") as fnull:
        with contextlib.redirect_stderr(fnull):
            traduccion = GoogleTranslator(source='auto', target='en').translate(texto_a_traducir)
    print(traduccion)
except Exception as e:
    print("Error al traducir")
    print("Debug:", e)
