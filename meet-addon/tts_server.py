#!/usr/bin/env python3
import http.server
import json
import subprocess
import os

PORT = 5005

class TTSHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        if self.path == '/speak':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            text = data.get('text', '')
            
            print(f"Speaking text: '{text}'")
            
            import hashlib
            try:
                # Generate a unique cache filename based on text md5 hash
                text_hash = hashlib.md5(text.encode('utf-8')).hexdigest()
                cache_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tts_cache')
                os.makedirs(cache_dir, exist_ok=True)
                cache_file = os.path.join(cache_dir, f"{text_hash}.wav")
                
                # Execute the speak.sh script with the text and cache file path using absolute path
                script_dir = os.path.dirname(os.path.abspath(__file__))
                speak_script = os.path.join(script_dir, "speak.sh")
                subprocess.run([speak_script, text, cache_file])
                
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "success"}).encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run():
    print(f"Starting local TTS Server on port {PORT}...")
    # Create speak.sh if it doesn't exist to give the user an easy starting point
    if not os.path.exists('speak.sh'):
        with open('speak.sh', 'w') as f:
            f.write('#!/bin/bash\n# Customize this file to run your piper setup!\n# Arguments: $1 = text, $2 = cache_file_path\n\nTEXT="$1"\nCACHE_FILE="$2"\n\nif [ -f "$CACHE_FILE" ]; then\n    paplay "$CACHE_FILE"\nelse\n    echo "$TEXT" | /home/user/piper/piper --model /home/user/piper/es_MX-claude-high.onnx --output_file "$CACHE_FILE" && paplay "$CACHE_FILE"\nfi\n')
        os.chmod('speak.sh', 0o755)
        
    server_address = ('', PORT)
    httpd = http.server.HTTPServer(server_address, TTSHandler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    print("\nStopping TTS Server.")

if __name__ == '__main__':
    run()
