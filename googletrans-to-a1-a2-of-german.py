import sys
import json
import urllib.request
import re

if len(sys.argv) < 2:
    print("Uso: python3 googletrans-to-a1-a2-of-german.py 'texto a traducir'")
    sys.exit(1)

text_to_translate = " ".join(sys.argv[1:])

MODEL = "hf.co/avemio/German-RAG-Mobius-DeepSeek-R1-ReDistill-LLAMA-8B-v1.1-SFT-DE-Q8_0-GGUF:latest"

prompt = f"""Bitte übersetze den folgenden Text ins Deutsche auf dem Niveau A1/A2. 
Der Text soll sehr einfach zu lesen sein, mit kurzen Sätzen und einfachem Vokabular (für Anfänger).
Gib NUR die deutsche Übersetzung aus, ohne weitere Kommentare oder Erklärungen.

Text: {text_to_translate}"""

data = {
    "model": MODEL,
    "prompt": prompt,
    "stream": False
}

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=json.dumps(data).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)

try:
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode("utf-8"))
        
        # Obtener la respuesta generada
        output = result.get("response", "")
        
        # Remover los bloques <think> generados por los modelos DeepSeek-R1
        output = re.sub(r'<think>.*?</think>', '', output, flags=re.DOTALL)
        
        # Imprimir el resultado limpio
        print(output.strip())
        
except Exception as e:
    print("Fehler bei der Übersetzung mit Ollama")
    # Descomenta la siguiente línea para ver el error real
    # print("Debug:", e)
