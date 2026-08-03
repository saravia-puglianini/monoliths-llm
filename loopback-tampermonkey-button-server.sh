#!/usr/bin/python3
"""
Servidor HTTP para control de Loopback ALSA + Tampermonkey
Detecta automáticamente cuando el micrófono/auricular JBL está conectado.
Soporta pipelines personalizados (Modo Normal o Modo Filtro) mediante /tmp/jbl_pipeline.
"""

import http.server
import socketserver
import json
import subprocess
import signal
import sys
import os
import time

PORT = 8888
PIPELINE_FILE = "/tmp/jbl_pipeline"
DEFAULT_PIPELINE = [
    "alsasrc", "device=plug:dsnoop_mic", "buffer-time=1", "latency-time=1", "blocksize=4", "!",
    "audio/x-raw, format=S16LE, rate=48000, channels=1", "!",
    "alsasink", "device=plug:dmix_speaker", "sync=false", "buffer-time=1", "latency-time=1", "blocksize=4"
]

# Asegurar entorno de usuario para ALSA/GStreamer si se ejecuta desde OpenRC/root
os.environ["HOME"] = "/home/user"

def is_jbl_connected():
    """Verifica mediante arecord si la tarjeta JBL Wireless está presente en ALSA."""
    try:
        res = subprocess.run(["arecord", "-l"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        return "Wireless" in res.stdout or "JBL" in res.stdout
    except Exception:
        return False

def is_gstreamer_running():
    """Verifica si el proceso de loopback en tiempo real está corriendo activamente."""
    try:
        res = subprocess.run(["doas", "pidof", "gst-launch-1.0"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False

def get_pipeline_cmd():
    if os.path.exists(PIPELINE_FILE):
        try:
            with open(PIPELINE_FILE, "r") as f:
                content = f.read().strip()
                if content:
                    return content.split()
        except Exception as e:
            print(f"[Loopback Server] Error leyendo {PIPELINE_FILE}: {e}")
    return DEFAULT_PIPELINE

def start_gstreamer():
    if not is_jbl_connected():
        print("[Loopback Server] JBL no detectado. Esperando conexión...")
        return False

    if not is_gstreamer_running():
        pipeline_args = get_pipeline_cmd()
        cmd = ["doas", "chrt", "-f", "99", "gst-launch-1.0", "-q"] + pipeline_args
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.3)
        print("[Loopback Server] Monitoreo iniciado.")
    return True

def stop_gstreamer():
    try:
        subprocess.run(["doas", "pkill", "-9", "-f", "gst-launch-1.0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("[Loopback Server] Monitoreo detenido.")
    except Exception as e:
        print(f"[Loopback Server] Error deteniendo gst-launch-1.0: {e}")

class LoopbackHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]
        jbl_on = is_jbl_connected()

        if path == "/pause":
            stop_gstreamer()
        elif path == "/resume":
            if jbl_on:
                start_gstreamer()
        elif path == "/toggle":
            if jbl_on:
                if is_gstreamer_running():
                    stop_gstreamer()
                else:
                    start_gstreamer()

        is_active = is_gstreamer_running() and jbl_on

        response_data = {
            "status": "success",
            "jbl_connected": jbl_on,
            "active": is_active
        }

        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(response_data).encode("utf-8"))
        except Exception as e:
            print(f"[Loopback Server] Error enviando respuesta: {e}")

    def log_message(self, format, *args):
        return

class ReusingServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server():
    if is_jbl_connected():
        start_gstreamer()

    try:
        server = ReusingServer(("0.0.0.0", PORT), LoopbackHandler)
        print(f"🚀 [Loopback Server] Escuchando servicio OpenRC en http://127.0.0.1:{PORT}")
    except Exception as e:
        print(f"Error iniciando servidor: {e}")
        sys.exit(1)

    def cleanup(sig, frame):
        stop_gstreamer()
        server.server_close()
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        cleanup(None, None)

if __name__ == "__main__":
    run_server()
