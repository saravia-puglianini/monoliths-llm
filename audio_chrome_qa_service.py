#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servicio Python de Validación QA de Audio y Speech Recognition en Google Chrome Stable.
Valida los 8 perfiles de audio (688 a 695) configurando ALSA y lanzando Chrome con --alsa-input-device.
"""

import os
import sys
import time
import json
import socket
import threading
import subprocess
from http.server import HTTPServer, SimpleHTTPRequestHandler
import urllib.parse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HTML_TEST_FILE = os.path.join(SCRIPT_DIR, "chrome_audio_speech_test.html")
REPORT_OUTPUT_FILE = "/tmp/qa_chrome_speech_report.json"

PROFILES = {
    "688": {
        "id": "688",
        "name": "OUT=sof-snd-dsp / IN=sof-snd-dsp",
        "script": "OUT=sof-snd-dsp-IN=sof-snd-dsp.sh",
        "alsa_device": "microfono_laptop",
        "description": "Altavoces SOF + Micrófono Interno SOF (Laptop)"
    },
    "689": {
        "id": "689",
        "name": "OUT=sof-snd-dsp / IN=sof-snd-dsp-FILTER",
        "script": "OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh",
        "alsa_device": "microfono_laptop",
        "description": "Altavoces SOF + Micrófono SOF con Filtro DSP (Laptop)"
    },
    "690": {
        "id": "690",
        "name": "OUT=jbl-usb-wireless / IN=jbl-usb-wireless",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Micrófono Inalámbrico JBL"
    },
    "691": {
        "id": "691",
        "name": "OUT=jbl-usb-wireless / IN=jbl-usb-wireless-FILTER",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Micrófono JBL con Filtro DSP"
    },
    "692": {
        "id": "692",
        "name": "OUT=jbl-usb-wireless / IN=jbl / LOOPBACK=jbl",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Micrófono JBL + Loopback en tiempo real"
    },
    "693": {
        "id": "693",
        "name": "OUT=jbl-usb-wireless / IN=jbl / FILTER-LOOPBACK=jbl",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Micrófono JBL Filtrado + Loopback"
    },
    "694": {
        "id": "694",
        "name": "OUT=jbl-usb-wireless / IN=jbl / LOOPBACK=Mic Laptop ➔ JBL",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Captura Mic Laptop redirigido a JBL"
    },
    "695": {
        "id": "695",
        "name": "OUT=jbl-usb-wireless / IN=jbl / FILTER-LOOPBACK=Mic Laptop ➔ JBL",
        "script": "OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh",
        "alsa_device": "entrada_buena_jbl",
        "description": "Auriculares JBL + Captura Mic Laptop Filtrado redirigido a JBL"
    }
}

# Estado global de la sesión de prueba actual
current_test_state = {
    "profile_id": None,
    "completed": False,
    "events": [],
    "last_telemetry": {},
    "result": None,
    "start_time": 0
}
state_lock = threading.Lock()


class QAAudioRequestHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silenciar logs http regulares
        return

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/test":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            with open(HTML_TEST_FILE, "rb") as f:
                self.wfile.write(f.read())
        elif parsed.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            with state_lock:
                self.wfile.write(json.dumps(current_test_state).encode("utf-8"))
        else:
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))

        if parsed.path == "/api/audio_chunk":
            raw_audio = self.rfile.read(length) if length > 0 else b""
            tmp_audio_path = f"/tmp/qa_audio_chunk_{int(time.time()*1000)}.webm"
            with open(tmp_audio_path, "wb") as f:
                f.write(raw_audio)
            
            # Notificar que se recibió chunk de voz
            with state_lock:
                current_test_state["speech_detected"] = True
                if not current_test_state["result"]:
                    current_test_state["result"] = {}
                current_test_state["result"]["speech_detected"] = True
            
            print(f"  [+] Audio de voz capturado y recibido ({len(raw_audio)} bytes)")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok","received":true}')
            return

        # Rutas de datos JSON
        raw_body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            body = raw_body.decode("utf-8", errors="ignore")
            data = json.loads(body)
        except Exception:
            data = {}

        if parsed.path == "/api/event":
            with state_lock:
                current_test_state["events"].append(data)
                evt_name = data.get("event")
                if evt_name == "telemetry":
                    current_test_state["last_telemetry"] = data
                elif evt_name == "speech_error":
                    print(f"  [!] Speech Error en Chrome: {data.get('error')}")
                elif evt_name == "speech_started":
                    print(f"  [*] Speech Recognition iniciado en Chrome.")
                elif evt_name == "speech_result":
                    print(f"  [+] Reconocido: {data.get('transcript')}")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        elif parsed.path == "/api/complete":
            with state_lock:
                current_test_state["completed"] = True
                current_test_state["result"] = data
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"received"}')
        else:
            self.send_response(404)
            self.end_headers()


def get_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


def run_system_command(cmd, shell=True):
    try:
        res = subprocess.run(cmd, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.returncode, res.stdout, res.stderr
    except Exception as e:
        return 1, "", str(e)


def apply_audio_profile(profile_info):
    script_path = os.path.join(SCRIPT_DIR, profile_info["script"])
    print(f"\n[+] Configurando perfil {profile_info['id']}: {profile_info['name']}...")
    if os.path.exists(script_path):
        code, out, err = run_system_command(f"bash {script_path}")
        if code != 0:
            print(f"[-] Advertencia ejecutando {profile_info['script']}: {err}")
    else:
        print(f"[-] Script no encontrado: {script_path}")


def launch_chrome(port, alsa_device, display=":0"):
    url = f"http://127.0.0.1:{port}/test"
    # Matar instancias previas para aplicar device ALSA
    run_system_command("pkill -9 chrome || true")
    time.sleep(0.3)

    chrome_cmd = [
        "google-chrome-stable",
        "--use-alsa",
        "--disable-audio-service-sandbox",
        f"--alsa-input-device={alsa_device}",
        "--use-fake-ui-for-media-stream",
        "--autoplay-policy=no-user-gesture-required",
        url
    ]

    env = os.environ.copy()
    env["DISPLAY"] = display

    print(f"[+] Lanzando Google Chrome Stable con ALSA input: '{alsa_device}'...")
    proc = subprocess.Popen(chrome_cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc


def inject_audio_test_tone(alsa_sink="default", freq=440, duration_sec=2):
    """Inyecta un tono de audio o sonido sintético si es necesario"""
    cmd = f"gst-launch-1.0 -q audiotestsrc wave=sine freq={freq} num-buffers={int(duration_sec*50)} ! audio/x-raw, rate=48000, channels=2 ! alsasink sync=false 2>/dev/null || speaker-test -c 2 -t sine -f {freq} -l 1 >/dev/null 2>&1 || true"
    threading.Thread(target=lambda: run_system_command(cmd), daemon=True).start()


def run_single_qa_test(profile_id, port, timeout_sec=25):
    profile = PROFILES.get(str(profile_id))
    if not profile:
        print(f"[-] Perfil ID {profile_id} no reconocido.")
        return None

    with state_lock:
        current_test_state["profile_id"] = profile_id
        current_test_state["completed"] = False
        current_test_state["events"] = []
        current_test_state["last_telemetry"] = {}
        current_test_state["result"] = None
        current_test_state["start_time"] = time.time()

    # 1. Configurar perfil de audio
    apply_audio_profile(profile)

    # 2. Lanzar Chrome
    chrome_proc = launch_chrome(port, profile["alsa_device"])

    print(f"\n========================================================")
    print(f"  PRUEBA ACTIVA: [{profile['id']}] {profile['name']}")
    print(f"  Dispositivo ALSA Input: {profile['alsa_device']}")
    print(f"  Instrucción: Habla por el micrófono seleccionado...")
    print(f"  Esperando datos en Chrome (Timeout: {timeout_sec}s)...")
    print(f"========================================================")

    start_t = time.time()
    last_print = 0

    while time.time() - start_t < timeout_sec:
        time.sleep(0.5)
        with state_lock:
            if current_test_state["completed"]:
                break
            telemetry = current_test_state.get("last_telemetry", {})
            max_lvl = telemetry.get("max_level", 0)
            act = telemetry.get("activity", 0)
            now = time.time()
            if now - last_print > 2.0:
                print(f"  -> [En progreso] Nivel RMS actual: {max_lvl}% | Muestras activas: {act}")
                last_print = now

    # Cerrar Chrome de la prueba
    try:
        chrome_proc.terminate()
        chrome_proc.wait(timeout=2)
    except Exception:
        run_system_command("pkill -9 chrome || true")

    with state_lock:
        res = current_test_state.get("result") or {}
        telemetry = current_test_state.get("last_telemetry", {})
        events = current_test_state.get("events", [])

    final_data = {
        "profile_id": profile["id"],
        "profile_name": profile["name"],
        "alsa_device": profile["alsa_device"],
        "max_audio_level": res.get("max_audio_level", telemetry.get("max_level", 0)),
        "activity_count": res.get("activity_count", telemetry.get("activity", 0)),
        "transcript": res.get("transcript", ""),
        "speech_detected": res.get("speech_detected", False) or current_test_state.get("speech_detected", False),
        "events_count": len(events),
        "passed_audio_level": (res.get("max_audio_level", telemetry.get("max_level", 0)) > 3),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    status_str = "PASÓ (Audio OK)" if final_data["passed_audio_level"] else "REVISAR (Señal baja o sin audio)"
    print(f"\n[+] Resultado Perfil {profile['id']}: {status_str}")
    print(f"    - Nivel Máximo RMS: {final_data['max_audio_level']}%")
    print(f"    - Detección de Actividad: {final_data['activity_count']} muestras")
    print(f"    - Transcripción de Voz: '{final_data['transcript'] or '(sin transcripción capturada)'}'")

    return final_data


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Validador QA de Audio y Speech en Google Chrome Stable")
    parser.add_argument("--profile", "-p", choices=list(PROFILES.keys()) + ["all"], default="all",
                        help="ID del perfil a probar (688 a 695 o 'all')")
    parser.add_argument("--timeout", "-t", type=int, default=20,
                        help="Tiempo de espera en segundos por prueba (def: 20s)")
    args = parser.parse_args()

    port = get_free_port()
    server = HTTPServer(("127.0.0.1", port), QAAudioRequestHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    print(f"[+] Servidor HTTP de soporte iniciado en http://127.0.0.1:{port}")

    profiles_to_run = list(PROFILES.keys()) if args.profile == "all" else [args.profile]
    results = []

    try:
        for pid in sorted(profiles_to_run):
            res = run_single_qa_test(pid, port, timeout_sec=args.timeout)
            if res:
                results.append(res)
            time.sleep(1)
    finally:
        server.shutdown()

    # Guardar reporte JSON
    with open(REPORT_OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f"\n========================================================")
    print(f"  RESUMEN FINAL DE PRUEBAS QA CHROME AUDIO & SPEECH")
    print(f"========================================================")
    for r in results:
        passed = "✔ PASÓ" if r["passed_audio_level"] else "✘ FALLÓ"
        print(f" [{r['profile_id']}] {r['profile_name']}: {passed} (RMS: {r['max_audio_level']}%, Voz: {'SI' if r['speech_detected'] else 'NO'})")
    print(f"\n[+] Reporte completo guardado en: {REPORT_OUTPUT_FILE}\n")


if __name__ == "__main__":
    main()
