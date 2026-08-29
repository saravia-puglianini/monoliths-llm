#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
registro-diario-broadway-daemon.py - Daemon supervisor para mantener siempre encendido
el servicio GTK3 Broadway en el puerto 8085. Si la ventana se cierra o cae, se relanza automáticamente.
"""
import os
import sys
import time
import subprocess
import signal
import urllib.request
import logging

LOG_FILE = os.path.expanduser("~/.justificar/registro-diario-broadway-daemon.log")
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

BROADWAY_PORT = 8085
BROADWAY_DISPLAY_NUM = 5
SCRIPT_PATH = "/home/user/monoliths-llm/registro-diario-broadwayd.py"

broadway_proc = None
app_proc = None


def is_broadway_alive():
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{BROADWAY_PORT}", timeout=1) as resp:
            return resp.status in (200, 404, 400)
    except Exception:
        return False


def start_broadwayd():
    global broadway_proc
    if not is_broadway_alive():
        logging.info("Iniciando broadwayd en el puerto %s...", BROADWAY_PORT)
        broadway_proc = subprocess.Popen(
            ["broadwayd", f"--port={BROADWAY_PORT}", f":{BROADWAY_DISPLAY_NUM}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        time.sleep(1)


def cleanup(signum=None, frame=None):
    global broadway_proc, app_proc
    logging.info("Cerrando servicio daemon...")
    if app_proc and app_proc.poll() is None:
        app_proc.terminate()
    if broadway_proc and broadway_proc.poll() is None:
        broadway_proc.terminate()
    sys.exit(0)


def run_forever():
    global app_proc
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    logging.info("Daemon supervisor iniciado para Registro Diario Broadway (puerto %s)", BROADWAY_PORT)

    env = os.environ.copy()
    env["GDK_BACKEND"] = "broadway"
    env["BROADWAY_DISPLAY"] = f":{BROADWAY_DISPLAY_NUM}"
    env["HOME"] = "/home/user"

    while True:
        try:
            # 1. Asegurar daemon broadwayd
            start_broadwayd()

            # 2. Iniciar / Supervisar la app GTK3
            if app_proc is None or app_proc.poll() is not None:
                logging.info("Iniciando instancia de %s...", SCRIPT_PATH)
                app_proc = subprocess.Popen(
                    [sys.executable, SCRIPT_PATH],
                    env=env,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            time.sleep(2)
        except Exception as e:
            logging.error("Error en supervisor daemon: %s", e)
            time.sleep(3)


if __name__ == "__main__":
    run_forever()
