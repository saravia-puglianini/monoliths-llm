import subprocess

input_file = "alicia-part-001.txt"
output_file = "alicia-part-001.de.A2.txt"

def traducir(linea):
    prompt = f"""Traduce al alemán nivel A2.
Usa frases simples y vocabulario básico.
No expliques nada.

Texto: {linea.strip()}
"""
    result = subprocess.run(
        ["ollama", "run", "mistral", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

with open(input_file, "r", encoding="utf-8") as f_in, \
     open(output_file, "w", encoding="utf-8") as f_out:

    for linea in f_in:
        if linea.strip() == "":
            f_out.write("\n")
            continue

        traduccion = traducir(linea)
        f_out.write(traduccion + "\n")

print("✅ Traducción completada.")