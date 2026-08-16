#!/usr/bin/env python3
"""
Servidor HTTP OpenRC para gestión y rotación de cargas SAP S/4HANA Cloud.
Puerto: 9995
Endpoints:
  - GET  /get-carga            : Devuelve la carga pendiente desde private.carga.txt
  - POST /auto-erase-carga     : Renombra private.carga.txt -> private.carga.YYYY-MM-DD.ready.txt
  - POST /write-carga          : Guarda una nueva carga en private.carga.txt
"""

import http.server
import socketserver
import json
import os
import sys
import datetime
import re

PORT = 9995
AUTO_SAP_DIR = os.path.expanduser("~/monoliths-llm/auto-sap")
CARGA_FILE = os.path.join(AUTO_SAP_DIR, "private.carga.txt")

class AutoEraseHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        if path in ["/get-carga", "/carga"]:
            if os.path.exists(CARGA_FILE) and os.path.getsize(CARGA_FILE) > 0:
                try:
                    with open(CARGA_FILE, "r", encoding="utf-8") as f:
                        content = f.read()

                    # Intentar parsear como JSON, de lo contrario estructurar líneas CSV
                    data = None
                    try:
                        data = json.loads(content)
                    except Exception:
                        lines = [l.strip() for l in content.split("\n") if l.strip()]
                        date_found = datetime.date.today().strftime("%Y-%m-%d")
                        items = []
                        for line in lines:
                            parts = line.split(";")
                            if len(parts) >= 3:
                                d_part = parts[0].strip()
                                if re.match(r"^\d{4}-\d{2}-\d{2}$", d_part):
                                    date_found = d_part
                                items.append({
                                    "fecha": d_part,
                                    "hora": parts[1].strip() if len(parts) > 1 else "",
                                    "proyecto": parts[2].strip() if len(parts) > 2 else "",
                                    "descripcion": parts[3].strip() if len(parts) > 3 else "",
                                    "url": parts[4].strip() if len(parts) > 4 else ""
                                })

                        data = {
                            "pending": True,
                            "fecha": date_found,
                            "raw": content,
                            "items": items
                        }

                    self.send_response(200)
                    self._send_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps(data).encode("utf-8"))
                    return
                except Exception as e:
                    self.send_response(500)
                    self._send_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))
                    return
            else:
                self.send_response(200)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"pending": False, "message": "No hay cargas pendientes"}).encode("utf-8"))
                return

        elif path in ["/auto-erase-carga", "/erase"]:
            self._handle_erase()
            return
        elif path in ["/clear-carga", "/clear"]:
            self._handle_clear()
            return

        self.send_response(404)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": "Ruta no encontrada"}).encode("utf-8"))

    def do_POST(self):
        path = self.path.split("?")[0]

        if path in ["/auto-erase-carga", "/erase"]:
            self._handle_erase()
            return
        elif path in ["/clear-carga", "/clear"]:
            self._handle_clear()
            return
        elif path == "/write-carga":
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8')
            os.makedirs(AUTO_SAP_DIR, exist_ok=True)
            with open(CARGA_FILE, "w", encoding="utf-8") as f:
                f.write(post_data)

            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": "Carga escrita correctamente"}).encode("utf-8"))
            return
        elif path == "/log-success-item":
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8')
            try:
                item = json.loads(post_data)
                fecha = item.get('fecha', datetime.date.today().strftime("%Y-%m-%d"))
                hora = item.get('hora', '')
                proyecto = item.get('proyecto', '')
                descripcion = item.get('descripcion', '')
                url = item.get('url', '')

                os.makedirs(AUTO_SAP_DIR, exist_ok=True)
                ready_filename = f"private.carga.{fecha}.ready.txt"
                ready_path = os.path.join(AUTO_SAP_DIR, ready_filename)

                ready_line = f"{fecha};{hora};{proyecto};{descripcion};{url}\n"
                with open(ready_path, "a", encoding="utf-8") as f:
                    f.write(ready_line)

                self.send_response(200)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "success", "message": f"Logged to {ready_filename}"}).encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))
            return

        self.send_response(404)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": "Ruta no encontrada"}).encode("utf-8"))

    def _handle_clear(self):
        try:
            if os.path.exists(CARGA_FILE):
                os.remove(CARGA_FILE)
            response = {"status": "success", "message": "Carga file cleared/deleted"}
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode("utf-8"))
        except Exception as e:
            self.send_response(500)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))

    def _handle_erase(self):
        if not os.path.exists(CARGA_FILE):
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "no_op", "message": "El archivo private.carga.txt no existe"}).encode("utf-8"))
            return

        try:
            # Extraer fecha del contenido
            target_date = datetime.date.today().strftime("%Y-%m-%d")
            with open(CARGA_FILE, "r", encoding="utf-8") as f:
                content = f.read()
                match = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", content)
                if match:
                    target_date = match.group(1)

            ready_filename = f"private.carga.{target_date}.ready.txt"
            ready_path = os.path.join(AUTO_SAP_DIR, ready_filename)

            if os.path.exists(ready_path):
                timestamp = datetime.datetime.now().strftime("%H%M%S")
                ready_filename = f"private.carga.{target_date}_{timestamp}.ready.txt"
                ready_path = os.path.join(AUTO_SAP_DIR, ready_filename)

            os.rename(CARGA_FILE, ready_path)
            print(f"[auto-erase-sap-carga] Archivo renombrado exitosamente: private.carga.txt -> {ready_filename}")

            response = {
                "status": "success",
                "message": "Carga rotada a ready correctamente",
                "fecha": target_date,
                "renamed_to": ready_filename
            }
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode("utf-8"))
        except Exception as e:
            print(f"[auto-erase-sap-carga] Error renombrando archivo: {e}")
            self.send_response(500)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))

    def log_message(self, format, *args):
        return

class ReusingServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server():
    os.makedirs(AUTO_SAP_DIR, exist_ok=True)
    try:
        server = ReusingServer(("0.0.0.0", PORT), AutoEraseHandler)
        print(f"🚀 [auto-erase-sap-carga] Servidor iniciado en http://localhost:{PORT}")
        server.serve_forever()
    except Exception as e:
        print(f"[auto-erase-sap-carga] Error iniciando servidor: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_server()
