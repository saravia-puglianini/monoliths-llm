# BUILD $HOME/googletrans/dist/googletrans-de
import sys
import os
import contextlib

with open(os.devnull, "w") as fnull:
    with contextlib.redirect_stderr(fnull):
        from deep_translator import GoogleTranslator

texto_a_traducir = " ".join(sys.argv[1:])

try:
    with open(os.devnull, "w") as fnull:
        with contextlib.redirect_stderr(fnull):
            traduccion = GoogleTranslator(source='auto', target='de').translate(texto_a_traducir)
    print(traduccion)
except Exception as e:
    print("Fehler bei der Übersetzung")
    print("Debug:", e)


# # HOW TO BUILD
# # Run
# 1. `deactivate`
# 2. `cd && mkdir -p googletrans && cd googletrans`
# 3. `bash`
# 4. `virtualenv -p python3 venv`
# 3. `source venv/bin/activate`
# 4. `echo 'googletrans==4.0.0-rc1' > requirements.txt`
# 5. `pip install -r requirements.txt`
# 5. `pip install legacy-cgi`
# 6. `ln -svf $HOME/monoliths-llm/googletrans-de.py ~/googletrans/`
# 7. `python3 googletrans-de.py 'we try translate the next'`
# # Binary
# 8. `pip install pyinstaller`
# 9. `pyinstaller --onefile googletrans-de.py`
# # so now you have $HOME/googletrans/dist/googletrans-de for run
# # test:
# `$HOME/googletrans/dist/googletrans-de 'Hola, bienvenido'`
