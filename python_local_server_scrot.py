import http.server
import socketserver
import subprocess
import base64
import os
import json

PORT = 5001
TEMP_FILE = "/tmp/scrot_capture.png"

class ScreenshotHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With')
        self.end_headers()

    def do_GET(self):
        if self.path == '/screenshot':
            try:
                # Take screenshot using scrot
                # -o flag overwrites the file
                subprocess.run(['scrot', '-o', TEMP_FILE], check=True)
                
                if os.path.exists(TEMP_FILE):
                    with open(TEMP_FILE, "rb") as image_file:
                        encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
                        
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {
                        "status": "success",
                        "base64": f"data:image/png;base64,{encoded_string}"
                    }
                    self.wfile.write(json.dumps(response).encode())
                    
                    # Clean up
                    os.remove(TEMP_FILE)
                else:
                    self.send_error(500, "Screenshot file not created")
            except Exception as e:
                self.send_response(500)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode())
        else:
            self.send_error(404)

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), ScreenshotHandler) as httpd:
        print(f"Scrot Screenshot Server running at http://localhost:{PORT}")
        print("Ready to take screenshots via /screenshot")
        httpd.serve_forever()
