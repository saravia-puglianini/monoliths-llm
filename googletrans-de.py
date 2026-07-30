# BUILD $HOME/googletrans/dist/googletrans-de
import sys
from googletrans import Translator

translator = Translator()

if len(sys.argv) < 2:
    print("Uso: python3 googletrans-de.py 'texto a traducir'")
    sys.exit(1)

text_to_translate = " ".join(sys.argv[1:])

try:
    result = translator.translate(text_to_translate, dest='de')
    print(result.text)
except Exception as e:
    # Mensaje en alemán cuando ocurre un error
    print("Fehler bei der Übersetzung")
    # Si quieres depuración, descomenta la siguiente línea:
    # print("Debug:", e)

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
