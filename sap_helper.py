#!/usr/bin/env python3
"""
SAP S/4HANA Cloud Web RPA Engine in Python
Automatización en segundo plano mediante Chrome DevTools Protocol (CDP)
y scripts de inyección SAP UI5 / DOM.
"""

import sys
import os
import time
import subprocess
import datetime
import json
import socket
import base64
import struct
import urllib.request
import urllib.parse
from collections import defaultdict

SAP_URL = "https://my419950.s4hana.cloud.sap/ui#TimeEntry-manageTimeEntry"
JUSTIFICAR_DIR = os.path.expanduser("~/.justificar")
LOG_FILE = os.path.join(JUSTIFICAR_DIR, "sap_helper.log")
CSV_FILE = os.path.join(JUSTIFICAR_DIR, "justificar.csv")
REGISTERED_JSON = os.path.join(JUSTIFICAR_DIR, "sap_registered.json")
CDP_PORT = 9222

def write_log(msg):
    os.makedirs(JUSTIFICAR_DIR, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] {msg}"
    print(log_msg)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(log_msg + "\n")

def load_registered_cache():
    if os.path.exists(REGISTERED_JSON):
        try:
            with open(REGISTERED_JSON, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_registered_cache(cache):
    os.makedirs(JUSTIFICAR_DIR, exist_ok=True)
    with open(REGISTERED_JSON, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2)

def is_cdp_active():
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{CDP_PORT}/json/version")
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status == 200
    except Exception:
        return False

def ensure_chrome_with_cdp():
    """
    Asegura que Google Chrome se ejecute con el puerto de depuración remota 9222 activo.
    """
    if is_cdp_active():
        write_log(f"[SAP RPA] Puerto CDP {CDP_PORT} ya está activo.")
        return True

    write_log(f"[SAP RPA] CDP no está activo. El proceso es gestionado automáticamente por el addon de Chrome y el servicio OpenRC (auto-erase-sap-carga).")
    return False

def cdp_get_sap_ws_url():
    """
    Obtiene la WebSocket URL de la pestaña de SAP S/4HANA Cloud.
    """
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{CDP_PORT}/json/list")
        with urllib.request.urlopen(req, timeout=3) as resp:
            tabs = json.loads(resp.read().decode("utf-8"))
            for tab in tabs:
                url = tab.get("url", "")
                if "s4hana.cloud.sap" in url or "TimeEntry" in url or "manageTimeEntry" in url:
                    ws_url = tab.get("webSocketDebuggerUrl")
                    if ws_url:
                        return ws_url

            # Si no está abierta la pestaña de SAP, abrir una nueva pestaña
            new_req = urllib.request.Request(f"http://127.0.0.1:{CDP_PORT}/json/new?{urllib.parse.quote(SAP_URL)}", method="PUT")
            with urllib.request.urlopen(new_req, timeout=5) as new_resp:
                new_tab = json.loads(new_resp.read().decode("utf-8"))
                return new_tab.get("webSocketDebuggerUrl")
    except Exception as e:
        write_log(f"[SAP RPA] Error al consultar pestañas CDP: {e}")
        return None

def cdp_send_eval(ws_url, expression):
    """
    Cliente WebSocket nativo en Python stdlib para evaluar JavaScript en la pestaña mediante CDP.
    """
    if not ws_url:
        return {"error": "No WebSocket URL provided"}

    try:
        url_parts = ws_url.replace("ws://", "").split("/", 1)
        host, port = url_parts[0].split(":")
        path = "/" + url_parts[1]

        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(60.0)
        s.connect((host, int(port)))

        sec_key = base64.b64encode(os.urandom(16)).decode("utf-8")
        handshake = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: 127.0.0.1:{port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {sec_key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        s.sendall(handshake.encode("utf-8"))
        resp = s.recv(4096)
        if b"101" not in resp:
            s.close()
            return {"error": f"WebSocket handshake failed: {resp.decode('utf-8', errors='ignore')}"}

        payload = json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {
                "expression": expression,
                "returnByValue": True,
                "awaitPromise": True
            }
        }).encode("utf-8")

        length = len(payload)
        mask_key = os.urandom(4)
        header = bytearray()
        header.append(0x81)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack(">H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack(">Q", length))

        masked_payload = bytearray(length)
        for i in range(length):
            masked_payload[i] = payload[i] ^ mask_key[i % 4]

        s.sendall(header + mask_key + masked_payload)
        raw_resp = b""
        start_t = time.time()
        while time.time() - start_t < 15:
            try:
                chunk = s.recv(65536)
                if not chunk:
                    break
                raw_resp += chunk
                if b'"id":1' in raw_resp or b'"id": 1' in raw_resp:
                    break
            except socket.timeout:
                break
        s.close()

        # Extraer frame WebSocket de respuesta (skip header)
        if raw_resp:
            start_idx = raw_resp.find(b"{")
            end_idx = raw_resp.rfind(b"}")
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                str_data = raw_resp[start_idx:end_idx+1].decode("utf-8", errors="ignore")
                try:
                    return json.loads(str_data)
                except Exception:
                    pass

        return {"status": "ok", "raw": raw_resp.decode("utf-8", errors="ignore")}
    except Exception as e:
        write_log(f"[SAP RPA] Error durante WebSocket CDP evaluation: {e}")
        return {"error": str(e)}

def generate_sap_ui5_rpa_js(target_date, project_hours_map):
    """
    Genera el script JavaScript de RPA para inyectar y ejecutar dentro de SAP Fiori (UI5).
    """
    entries_json = json.dumps(project_hours_map)
    js_code = f"""
(async function rpaSAP() {{
    const targetDate = "{target_date}";
    const entries = {entries_json};
    console.log("[RPA SAP] Ejecutando registro automático para " + targetDate, entries);

    const logStatus = [];

    // Helper para esperar elementos DOM / UI5
    function wait(ms) {{ return new Promise(resolve => setTimeout(resolve, ms)); }}

    // 1. Verificar si SAP Fiori está cargado
    let retries = 0;
    while (retries < 15) {{
        if (typeof sap !== 'undefined' && sap.ui && sap.ui.getCore) break;
        await wait(1000);
        retries++;
    }}

    // 0. Dar foco a la tabla y enviar 10 veces Ctrl + - (Zoom Out)
    let gridTable = document.querySelector('[id*="timesheetMain"], .sapTetrisTable, table');
    if (gridTable) {{
        try {{
            gridTable.focus();
            gridTable.scrollIntoView({{ block: 'center' }});
        }} catch(e) {{}}
    }}
    for (let z = 1; z <= 10; z++) {{
        let currentZoom = Math.max(0.5, 1.0 - (z * 0.05));
        if (document.body) {{ document.body.style.zoom = `${{currentZoom}}`; }}
        let tgt = document.activeElement || gridTable || document.body || window;
        try {{ if (tgt.focus) tgt.focus(); }} catch (e) {{}}
        tgt.dispatchEvent(new KeyboardEvent('keydown', {{ key: '-', code: 'Minus', keyCode: 189, ctrlKey: true, bubbles: true }}));
        tgt.dispatchEvent(new KeyboardEvent('keyup', {{ key: '-', code: 'Minus', keyCode: 189, ctrlKey: true, bubbles: true }}));
        tgt.dispatchEvent(new KeyboardEvent('keydown', {{ key: '-', code: 'NumpadSubtract', keyCode: 109, ctrlKey: true, bubbles: true }}));
        tgt.dispatchEvent(new KeyboardEvent('keyup', {{ key: '-', code: 'NumpadSubtract', keyCode: 109, ctrlKey: true, bubbles: true }}));
        await wait(120);
    }}
    await wait(400);

    // Intentar interactuar vía DOM & SAP UI5 Core
    for (const item of entries) {{
        try {{
            console.log("[RPA SAP] Imputando: " + item.proyecto + " | Horas: " + item.horas);
            
            // Buscar botón 'Crear' / 'Nuevo' / '+' en Fiori
            let btnCreate = document.querySelector('button[id*="create"], button[id*="new"], button[title*="Crear"], button[title*="Create"], button[aria-label*="Crear"]');
            if (btnCreate) {{
                btnCreate.click();
                await wait(1500);
            }}

            // Buscar entradas de Fecha, Proyecto/Elemento PEP, Horas y Nota
            let inputs = document.querySelectorAll('input, textarea');
            let dateFilled = false, projFilled = false, hrsFilled = false, noteFilled = false;

            inputs.forEach(el => {{
                let aria = (el.getAttribute('aria-label') || '').toLowerCase();
                let placeholder = (el.getAttribute('placeholder') || '').toLowerCase();
                let id = (el.id || '').toLowerCase();

                if (!dateFilled && (aria.includes('fecha') || aria.includes('date') || placeholder.includes('yyyy') || id.includes('date'))) {{
                    el.value = targetDate;
                    el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('change', {{ bubbles: true }}));
                    dateFilled = true;
                }} else if (!hrsFilled && (aria.includes('hora') || aria.includes('duraci') || aria.includes('duration') || id.includes('hour') || id.includes('duration'))) {{
                    let durVal = item.horas || "01:00";
                    el.value = durVal;
                    el.setAttribute('value', durVal);
                    el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('change', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('blur', {{ bubbles: true }}));
                    if (typeof sap !== 'undefined' && sap?.ui?.getCore && el.id) {{
                        try {{
                            const ctrl = sap.ui.getCore().byId(el.id.replace(/-inner$/, ''));
                            if (ctrl) {{
                                if (ctrl.setValue) ctrl.setValue(durVal);
                                if (ctrl.fireChange) ctrl.fireChange({{ value: durVal }});
                                if (ctrl.fireLiveChange) ctrl.fireLiveChange({{ value: durVal }});
                            }}
                        }} catch(e) {{}}
                    }}
                    hrsFilled = true;
                }} else if (!projFilled && (aria.includes('proyect') || aria.includes('pep') || aria.includes('wbs') || id.includes('project') || id.includes('wbs'))) {{
                    el.value = item.proyecto;
                    el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('change', {{ bubbles: true }}));
                    projFilled = true;
                }} else if (!noteFilled && (el.tagName === 'TEXTAREA' || aria.includes('nota') || aria.includes('descrip') || id.includes('note') || id.includes('comment'))) {{
                    el.value = item.descripcion;
                    el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('change', {{ bubbles: true }}));
                    noteFilled = true;
                }}
            }});

            await wait(1000);

            // Buscar y presionar botón Guardar / Enviar
            let btnSave = document.querySelector('button[id*="save"], button[title*="Guardar"], button[aria-label*="Guardar"], button[title*="Save"]');
            if (btnSave) {{
                btnSave.click();
                await wait(2000);
            }}

            logStatus.push({{ proyecto: item.proyecto, horas: item.horas, success: true }});
        }} catch (err) {{
            console.error("[RPA SAP] Error en ítem: ", err);
            logStatus.push({{ proyecto: item.proyecto, horas: item.horas, success: false, error: err.toString() }});
        }}
    }}

    return {{ status: "completed", date: targetDate, details: logStatus }};
}})();
"""
    return js_code

def run_web_rpa_for_date(target_date):
    """
    Ejecuta el RPA Web completo en segundo plano para una fecha específica.
    """
    if not os.path.exists(CSV_FILE):
        write_log(f"[SAP RPA] No existe el archivo {CSV_FILE}")
        return False

    # 1. Leer y agrupar entradas para la fecha
    entries = []
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split(";")
            if len(parts) >= 4 and parts[0] == target_date:
                entries.append({
                    "proyecto": parts[2],
                    "descripcion": parts[3]
                })

    if not entries:
        write_log(f"[SAP RPA] No hay registros locales para regularizar en la fecha {target_date}.")
        return False

    project_map = defaultdict(lambda: {"horas": 0, "descs": set()})
    for e in entries:
        p = e["proyecto"]
        project_map[p]["horas"] += 1
        if e["descripcion"]:
            project_map[p]["descs"].add(e["descripcion"])

    rpa_items = []
    for proj, data in project_map.items():
        rpa_items.append({
            "proyecto": proj,
            "horas": str(data["horas"]),
            "descripcion": " | ".join(data["descs"])
        })

    write_log(f"[SAP RPA] Preparando RPA Web para {target_date}: {len(rpa_items)} grupo(s) de tareas ({len(entries)} horas).")

    # 2. Asegurar que Chrome con CDP esté disponible
    if not ensure_chrome_with_cdp():
        write_log(f"[SAP RPA] No se pudo establecer conexión CDP con Chrome. Reintentando...")
        return False

    # 3. Obtener WebSocket URL de la pestaña SAP
    ws_url = cdp_get_sap_ws_url()
    if not ws_url:
        write_log(f"[SAP RPA] No se encontró la pestaña de SAP Cloud en CDP.")
        return False

    # 4. Esperar estabilización de la página e inyectar y ejecutar RPA Script
    write_log(f"[SAP RPA] Esperando carga inicial de SAP Fiori...")
    time.sleep(6) # Dar tiempo a que la pestaña abra y estabilice el contexto
    write_log(f"[SAP RPA] Inyectando motor de automatización en SAP Cloud via CDP...")
    js_script = generate_sap_ui5_rpa_js(target_date, rpa_items)

    res = None
    for attempt in range(1, 4):
        res = cdp_send_eval(ws_url, js_script)
        if res and "error" in res and "destroyed" in str(res["error"]):
            write_log(f"[SAP RPA] Intento {attempt}: Contexto en navegación. Esperando 4s más...")
            time.sleep(4)
        else:
            break

    write_log(f"[SAP RPA] Resultado de ejecución RPA en SAP para {target_date}: {json.dumps(res)}")

    # Guardar en cache de registros completados
    cache = load_registered_cache()
    cache[target_date] = {
        "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_hours": len(entries),
        "items": rpa_items,
        "status": "COMPLETED_VIA_RPA"
    }
    save_registered_cache(cache)
    return True

def regularize_all_pending():
    """
    Recorre todo el historial en justificar.csv e imputa automáticamente en SAP
    todas las fechas pendientes en segundo plano.
    """
    if not os.path.exists(CSV_FILE):
        write_log(f"[SAP RPA] Archivo CSV no encontrado.")
        return

    dates_in_csv = set()
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split(";")
            if len(parts) >= 4 and parts[0]:
                dates_in_csv.add(parts[0])

    sorted_dates = sorted(list(dates_in_csv))
    cache = load_registered_cache()

    write_log(f"[SAP RPA] Iniciando regularización masiva. Fechas totales en historial: {len(sorted_dates)}")
    count = 0
    for d in sorted_dates:
        if d not in cache or cache[d].get("status") != "COMPLETED_VIA_RPA":
            write_log(f"[SAP RPA] ---> Procesando fecha pendiente: {d}")
            success = run_web_rpa_for_date(d)
            if success:
                count += 1
            time.sleep(2) # Pausa entre días para estabilizar Fiori

    write_log(f"[SAP RPA] Regularización masiva finalizada. Fechas procesadas automáticamente: {count}")

def get_day_report(target_date):
    """
    Genera un informe detallado y resumido por ticket/proyecto para la fecha especificada.
    """
    if not os.path.exists(CSV_FILE):
        write_log(f"[SAP Helper] No se encontró el archivo de datos {CSV_FILE}")
        return
        
    entries = []
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split(";")
            if len(parts) >= 4 and parts[0] == target_date:
                entries.append({
                    "fecha": parts[0],
                    "hora": parts[1],
                    "proyecto": parts[2],
                    "descripcion": parts[3],
                    "link": parts[4] if len(parts) > 4 else ""
                })
                
    if not entries:
        report_text = f"=== REGISTRO SAP / JIRA PARA FECHA: {target_date} ===\nNo hay registros encontrados para esta fecha."
        print(report_text)
        return report_text

    project_hours = defaultdict(int)
    project_descs = defaultdict(set)
    
    for e in entries:
        p = e["proyecto"]
        project_hours[p] += 1
        if e["descripcion"]:
            project_descs[p].add(e["descripcion"])
            
    lines = []
    lines.append(f"==========================================================")
    lines.append(f"   LOG DE HORAS PARA REGULARIZACIÓN EN SAP - {target_date}")
    lines.append(f"==========================================================")
    lines.append(f"Total registros: {len(entries)} hora(s)\n")
    lines.append("--- DETALLE HORARIA ---")
    for e in entries:
        lines.append(f"• {e['hora']} | [{e['proyecto']}] {e['descripcion']}")
        
    lines.append("\n--- RESUMEN POR PROYECTO / TICKET (CONSOLIDADO PARA SAP) ---")
    for proj, hrs in project_hours.items():
        descs = " | ".join(project_descs[proj])
        lines.append(f"• Ticket/Proyecto: {proj}")
        lines.append(f"  Horas Totales  : {hrs}h")
        lines.append(f"  Descripción    : {descs}")
        lines.append("")

    lines.append("==========================================================")
    
    report_output = "\n".join(lines)
    print(report_output)
    write_log(f"[SAP Helper] Reporte generado para fecha {target_date} ({len(entries)} horas).")
    return report_output

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: sap_helper.py [log-time <horas> [fecha]] | [auto-log [fecha]] | [regularize-all] | [report <fecha>] | [logs]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    if cmd in ["log-time", "auto-log"]:
        hrs = sys.argv[2] if len(sys.argv) > 2 else "1"
        date_str = sys.argv[3] if len(sys.argv) > 3 else datetime.date.today().strftime("%Y-%m-%d")
        run_web_rpa_for_date(date_str)
    elif cmd in ["regularize-all", "batch"]:
        regularize_all_pending()
    elif cmd in ["report", "show-day", "regularizar"]:
        date_str = sys.argv[2] if len(sys.argv) > 2 else "2026-07-27"
        get_day_report(date_str)
    elif cmd == "logs":
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                print(f.read())
        else:
            print("No existe archivo de log aún.")
    else:
        print(f"Comando no reconocido: {cmd}")
        sys.exit(1)


