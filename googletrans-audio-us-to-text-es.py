import speech_recognition as sr
from deep_translator import GoogleTranslator
import sys

# Configurar el recognizer
r = sr.Recognizer()

# Cargar audio
audio_path = sys.argv[1]  # ejemplo: 'audio_en.wav'
with sr.AudioFile(audio_path) as source:
    audio_data = r.record(source)

try:
    # Transcribir audio a texto en inglés
    texto_en = r.recognize_google(audio_data, language='en-US')
    print("Texto original:", texto_en)

    # Traducir a español
    traduccion = GoogleTranslator(source='auto', target='es').translate(texto_en)
    print("Traducción:", traduccion)

except sr.UnknownValueError:
    print("No se pudo entender el audio")
except sr.RequestError as e:
    print("Error con el servicio de reconocimiento de voz:", e)
except Exception as e:
    print("Error al traducir:", e)

# # Run
# 0. bash
# 1. deactivate; cd && mkdir -p $HOME/googletrans && cd $HOME/googletrans
# 2. virtualenv -p python3 venv
# 3. source venv/bin/activate
# 4. pip install speechrecognition deep-translator --prefer-binary
# 5. ln -svf $HOME/googletrans/googletrans-audio-us-to-text-es.py $HOME/googletrans/
# 6. python3 $HOME/googletrans/googletrans-audio-us-to-text-es.py 'hi, welcome'
# # Binary
# pip install pyinstaller
# pyinstaller --onefile googletrans-audio-us-to-text-es.py
# so now you have $HOME/googletrans/dist/googletrans-audio-us-to-text-es for run
