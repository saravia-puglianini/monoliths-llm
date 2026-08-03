#!/usr/bin/python3
"""
Servidor HTTP para control de Loopback ALSA + Tampermonkey
Detecta automáticamente cuando el micrófono/auricular JBL está conectado.
"""

import http.server
import socketserver
import json
import subprocess
import signal
import sys
import time
import os

PORT = 8888
GST_PROCESS = None
INPUT_DEV = "plug:dsnoop_mic"
OUTPUT_DEV = "default"


# Asegurar entorno de usuario para ALSA/GStreamer si se ejecuta desde OpenRC/root
os.environ["HOME"] = "/home/user"

def is_jbl_connected():
    """Verifica mediante arecord si la tarjeta JBL Wireless está presente en ALSA."""
    try:
        res = subprocess.run(["arecord", "-l"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        return "Wireless" in res.stdout or "JBL" in res.stdout
    except Exception:
        return False

def start_gstreamer():
    global GST_PROCESS
    if not is_jbl_connected():
        print("[Loopback Server] JBL no detectado. Esperando conexión...")
        return None

    if GST_PROCESS is None or GST_PROCESS.poll() is not None:
        cmd = [
            "doas", "chrt", "-f", "99",
            "gst-launch-1.0", "-q",
            "alsasrc", "device=plug:dsnoop_mic", "buffer-time=1", "latency-time=1", "blocksize=4", "!",
            "audio/x-raw, format=S16LE, rate=48000, channels=1", "!",
            "alsasink", "device=plug:dmix_speaker", "sync=false", "buffer-time=1", "latency-time=1", "blocksize=4"
        ]

        GST_PROCESS = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"[Loopback Server] JBL detectado. Monitoreo iniciado (PID: {GST_PROCESS.pid})")
    return GST_PROCESS.pid if GST_PROCESS else None

def stop_gstreamer():
    global GST_PROCESS
    if GST_PROCESS is not None:
        if GST_PROCESS.poll() is None:
            GST_PROCESS.terminate()
            try:
                GST_PROCESS.wait(timeout=1)
            except subprocess.TimeoutExpired:
                GST_PROCESS.kill()
            print("[Loopback Server] Monitoreo pausado/detenido.")
        GST_PROCESS = None
    subprocess.run(["doas", "killall", "-9", "gst-launch-1.0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

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
        global GST_PROCESS

        path = self.path.split("?")[0]
        jbl_on = is_jbl_connected()

        if path == "/pause":
            stop_gstreamer()
        elif path == "/resume":
            if jbl_on:
                start_gstreamer()
        elif path == "/toggle":
            if jbl_on:
                if GST_PROCESS is not None and GST_PROCESS.poll() is None:
                    stop_gstreamer()
                else:
                    start_gstreamer()

        is_active = (GST_PROCESS is not None and GST_PROCESS.poll() is None and jbl_on)
        response_data = {
            "status": "success",
            "jbl_connected": jbl_on,
            "active": is_active,
            "pid": GST_PROCESS.pid if is_active else None
        }

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode("utf-8"))

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
