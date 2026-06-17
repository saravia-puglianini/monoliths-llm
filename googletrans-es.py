# BUILD $HOME/googletrans/dist/googletrans-es
import sys
import os
import contextlib

# Redirigir stderr temporalmente a null
with open(os.devnull, "w") as fnull:
    with contextlib.redirect_stderr(fnull):
        from deep_translator import GoogleTranslator

import sys
texto_a_traducir = " ".join(sys.argv[1:])

try:
    with open(os.devnull, "w") as fnull:
        with contextlib.redirect_stderr(fnull):
            traduccion = GoogleTranslator(source='auto', target='es').translate(texto_a_traducir)
    print(traduccion)
except Exception as e:
    print("Error al traducir")
    print("Debug:", e)

# HOW TO BUILD
# Run
# 1. `deactivate`
# 2. `cd && mkdir -p googletrans && cd googletrans`
# 3. `virtualenv -p python3 venv`
# 4. `bash`
# 5. `source venv/bin/activate`
# 6. `pip install deep-translator --prefer-binary`
# 7. `ln -svf $HOME/monoliths-llm/googletrans-es.py $HOME/googletrans/`
# 8. `python3 googletrans-es.py 'we try translate the next'`
# # Binary
# 9. `pip install pyinstaller`
# 10. `pyinstaller --onefile googletrans-es.py`
# # so now you have $HOME/googletrans/dist/googletrans-es for run
# 11. `$HOME/googletrans/dist/googletrans-es 'ready'`