#!/bin/bash
# Wrapper bash para ejecutar el servidor Python de control Loopback ALSA + Tampermonkey

python3 -c '
import http.server
import socketserver
import json
import subprocess
import signal
import sys

PORT = 8888
GST_PROCESS = None
INPUT_DEV = "plug:dsnoop_mic"
OUTPUT_DEV = "plug:default"

def start_gstreamer():
    global GST_PROCESS
    if GST_PROCESS is None or GST_PROCESS.poll() is not None:
        cmd = [
            "gst-launch-1.0", "-q",
            "alsasrc", f"device={INPUT_DEV}", "buffer-time=1", "latency-time=1", "blocksize=32", "!",
            "audioconvert", "!",
            "audioresample", "quality=0", "!",
            "audio/x-raw, rate=48000, channels=1", "!",
            "audiochebband", "mode=band-pass", "lower-frequency=200", "upper-frequency=3000", "poles=2", "!",
            "audiodynamic", "mode=expander", "threshold=0.008", "ratio=2.0", "characteristics=soft-knee", "!",
            "audioconvert", "!",
            "alsasink", f"device={OUTPUT_DEV}", "sync=false", "buffer-time=1", "latency-time=1", "blocksize=32"
        ]
        GST_PROCESS = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"[Loopback Server] Monitoreo iniciado (PID: {GST_PROCESS.pid})")
    return GST_PROCESS.pid

def stop_gstreamer():
    global GST_PROCESS
    if GST_PROCESS is not None:
        if GST_PROCESS.poll() is None:
            GST_PROCESS.terminate()
            try:
                GST_PROCESS.wait(timeout=1)
            except subprocess.TimeoutExpired:
                GST_PROCESS.kill()
            print("[Loopback Server] Monitoreo pausado.")
        GST_PROCESS = None

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

        if path == "/pause":
            stop_gstreamer()
        elif path == "/resume":
            start_gstreamer()
        elif path == "/toggle":
            if GST_PROCESS is not None and GST_PROCESS.poll() is None:
                stop_gstreamer()
            else:
                start_gstreamer()

        is_active = (GST_PROCESS is not None and GST_PROCESS.poll() is None)
        response_data = {
            "status": "success",
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

def run_server():
    start_gstreamer()
    
    socketserver.TCPServer.allow_reuse_address = True
    server = socketserver.TCPServer(("127.0.0.1", PORT), LoopbackHandler)
    print(f"🚀 [Loopback Server] Escuchando en http://127.0.0.1:{PORT}")

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
'
