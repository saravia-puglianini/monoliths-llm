import http.server
import socketserver
import json
import subprocess
import urllib.parse
import os
import tempfile
from datetime import datetime

PORT = 9999
LOG_FILE = "/home/user/monoliths-llm/debug_remote.log"
PIPER_BIN = "/home/user/piper/piper"
CLAUDE_MODEL = "/home/user/piper/es_MX-claude-high.onnx"

class LogHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == '/tts':
            params = urllib.parse.parse_qs(parsed.query)
            text = params.get('text', [''])[0]
            if not text:
                self.send_response(400)
                self.end_headers()
                return

            try:
                # Sintetizar usando el binario y modelo real de Piper Claude
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_wav:
                    tmp_wav_path = tmp_wav.name

                cmd = [
                    PIPER_BIN,
                    "--model", CLAUDE_MODEL,
                    "--output_file", tmp_wav_path
                ]

                proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                proc.communicate(input=text.encode('utf-8'))

                if os.path.exists(tmp_wav_path):
                    with open(tmp_wav_path, 'rb') as f:
                        wav_data = f.read()
                    os.remove(tmp_wav_path)

                    self.send_response(200)
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.send_header('Content-Type', 'audio/wav')
                    self.send_header('Content-Length', str(len(wav_data)))
                    self.end_headers()
                    self.wfile.write(wav_data)
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] [PIPER CLAUDE TTS] Audio WAV generado ({len(wav_data)} bytes) para: '{text[:30]}...'", flush=True)
                    return
                else:
                    self.send_response(500)
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    return

            except Exception as e:
                print(f"[PIPER TTS ERROR] {e}", flush=True)
                self.send_response(500)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

        try:
            payload = json.loads(post_data.decode('utf-8'))
            now = datetime.now().strftime('%H:%M:%S.%f')[:-3]
            log_line = f"[{now}] [{payload.get('level', 'INFO')}] {payload.get('tag', 'General')}: {payload.get('message', '')} | Data: {json.dumps(payload.get('data', {}), ensure_ascii=False)}\n"
            
            print(log_line, end='', flush=True)
            with open(LOG_FILE, 'a', encoding='utf-8') as f:
                f.write(log_line)
        except Exception as e:
            print(f"[LOG SERVER ERROR] {e}", flush=True)

if __name__ == "__main__":
    with open(LOG_FILE, 'w', encoding='utf-8') as f:
        f.write(f"=== SERVIDOR PIPER CLAUDE TTS INICIADO {datetime.now()} ===\n")
        
    print(f"🚀 Servidor Piper Claude TTS activo en http://localhost:{PORT}")
    with socketserver.TCPServer(("0.0.0.0", PORT), LogHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor detenido.")
