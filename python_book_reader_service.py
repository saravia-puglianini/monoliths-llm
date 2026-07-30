#!/usr/bin/env python3

import subprocess
import time
import re
import os
import signal
from pathlib import Path

# --- CONFIGURACIÓN ---
PATTERN = re.compile(
    r"^bash\s+~/monoliths-llm/vociferate-pdf\.sh\s+(~/Libros/.+\.pdf)$"
)

STOP_PATTERN = re.compile(r"^sto.*\.txt$", re.IGNORECASE)
DOWNLOADS = Path.home() / "Descargas"
STOP_FILE_TMP = Path("/tmp/STOP")

# --- VARIABLES DE ESTADO ---
proc = None
current_pdf = None
seen_stop_files = set()

def cleanup_stop_files():
    """Limpia /tmp/STOP y todos los sto*.txt en Descargas"""
    print("Iniciando limpieza de archivos stop...")
    
    # 1. Borrar /tmp/STOP
    if STOP_FILE_TMP.exists():
        try:
            print(f"Borrando {STOP_FILE_TMP}")
            STOP_FILE_TMP.unlink()
        except Exception as e:
            print(f"Error al borrar {STOP_FILE_TMP}: {e}")

    # 2. Borrar ~/Descargas/sto*txt
    for f_stop in DOWNLOADS.glob("sto*.txt"):
        try:
            print(f"Limpiando archivo residual: {f_stop.name}")
            f_stop.unlink()
        except Exception as e:
            print(f"No se pudo borrar {f_stop.name}: {e}")

def clipboard():
    try:
        return subprocess.check_output(
            ["xclip", "-selection", "clipboard", "-o"],
            text=True,
            errors="ignore",
            timeout=2  # Evita que el servicio se quede colgado si xclip se bloquea
        ).strip()
    except subprocess.TimeoutExpired:
        print("Error: xclip tardó demasiado (timeout).")
        return ""
    except Exception as e:
        # print(f"Error leyendo portapapeles: {e}")
        return ""

def check_stop_files():
    global seen_stop_files
    try:
        current_files = set()
        for f in DOWNLOADS.iterdir():
            if f.is_file() and STOP_PATTERN.match(f.name):
                current_files.add(f.name)
                if f.name not in seen_stop_files:
                    print(f"Nuevo stop detectado en Descargas: {f.name}")
                    STOP_FILE_TMP.touch()

        seen_stop_files = current_files
    except Exception as e:
        print("Error revisando stop files:", e)

# --- EJECUCIÓN AL ARRANCAR EL SCRIPT ---
cleanup_stop_files()

# --- BUCLE PRINCIPAL ---
print("Servicio escuchando el portapapeles...")
last_text = ""

while True:
    try:
        text = clipboard()
        
        if text != last_text:
            last_text = text
            match = PATTERN.match(text)

            if match:
                pdf_path = match.group(1)
                print(f"\n>>> Comando detectado: {text}")

                # Matar proceso anterior si existe
                if proc and proc.poll() is None:
                    print("Matando proceso anterior...")
                    try:
                        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                    except ProcessLookupError:
                        pass

                # Limpieza antes de lanzar el nuevo proceso
                cleanup_stop_files()
                seen_stop_files.clear()

                # Lanzar nuevo proceso
                cmd = os.path.expanduser(text)
                print(f"Ejecutando: {cmd}")
                proc = subprocess.Popen(
                    cmd,
                    shell=True,
                    preexec_fn=os.setsid
                )

        check_stop_files()
        time.sleep(0.1)

    except KeyboardInterrupt:
        print("\nSaliendo...")
        break
    except Exception as e:
        print("Error general:", e)
        time.sleep(2)