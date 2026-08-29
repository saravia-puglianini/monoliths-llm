#!/usr/bin/env python3
"""Local web dispatcher for ~/amd64gnu+linux scripts."""

import html
import json
import os
import re
import secrets
import signal
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


HOST = "127.0.0.1"
PORT = 9099
HOME = Path("/home/user")
SCRIPT_DIR = HOME / "amd64gnu+linux"
STATE_DIR = HOME / ".local" / "state" / "assembly-dispatch-9099"
LOG_DIR = STATE_DIR / "logs"
STATE_FILE = STATE_DIR / "active.json"
STOP_TIMEOUT = 12.0
MAX_LOG_BYTES = 512 * 1024
ANSI_ESCAPE = re.compile(rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")


def discover_actions():
    actions = []
    if not SCRIPT_DIR.is_dir():
        return actions
    for script in sorted(SCRIPT_DIR.glob("*.sh"), key=lambda p: p.name.lower()):
        name = script.stem
        project = HOME / name
        if not (project.is_dir() or project.is_symlink()):
            continue
        actions.append({"id": name, "name": name, "script": script, "mock": False})
        if (project / "mock").is_dir():
            actions.append({"id": name + "::mock", "name": name + " mock", "script": script, "mock": True})
    return actions


class ProcessManager:
    def __init__(self):
        self.lock = threading.RLock()
        self.active = None
        self.process = None
        self.last = None
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        self._recover_state()

    @staticmethod
    def _group_alive(pgid):
        try:
            os.killpg(pgid, 0)
            return True
        except (ProcessLookupError, PermissionError):
            return False

    def _recover_state(self):
        try:
            saved = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            pgid = int(saved["pgid"])
            if self._group_alive(pgid):
                self.active = saved
            else:
                STATE_FILE.unlink(missing_ok=True)
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            STATE_FILE.unlink(missing_ok=True)

    def _save(self):
        if self.active:
            temp = STATE_FILE.with_suffix(".tmp")
            temp.write_text(json.dumps(self.active, ensure_ascii=False), encoding="utf-8")
            temp.replace(STATE_FILE)
        else:
            STATE_FILE.unlink(missing_ok=True)

    def status(self):
        with self.lock:
            if self.process is not None:
                self.process.poll()
            if self.active and not self._group_alive(int(self.active["pgid"])):
                self.active["ended_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
                self.active["result"] = "finalizada"
                self.last = dict(self.active)
                self.active = None
                self.process = None
                self._save()
            return dict(self.active) if self.active else None

    def stop(self):
        with self.lock:
            active = self.status()
            if not active:
                return None
            pgid = int(active["pgid"])
            try:
                os.killpg(pgid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            deadline = time.monotonic() + STOP_TIMEOUT
            if self.process is not None and self.process.pid == pgid:
                try:
                    self.process.wait(timeout=STOP_TIMEOUT)
                except subprocess.TimeoutExpired:
                    pass
            while self._group_alive(pgid) and time.monotonic() < deadline:
                time.sleep(0.15)
            if self._group_alive(pgid):
                try:
                    os.killpg(pgid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                time.sleep(0.2)
            stopped = active["name"]
            active["ended_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
            active["result"] = "detenida"
            self.last = dict(active)
            self.active = None
            self.process = None
            self._save()
            return stopped

    def start(self, action_id):
        with self.lock:
            action = next((a for a in discover_actions() if a["id"] == action_id), None)
            if not action:
                raise ValueError("La acción ya no existe o no está habilitada")

            previous = self.stop()
            timestamp = time.strftime("%Y%m%d-%H%M%S")
            safe_id = action_id.replace("::", "-")
            log_path = LOG_DIR / f"{timestamp}-{safe_id}.log"
            command = ["/bin/bash", str(action["script"])]
            if action["mock"]:
                command.append("mock")
            env = os.environ.copy()
            env.update({"HOME": str(HOME), "USER": "user", "LOGNAME": "user"})
            with log_path.open("ab", buffering=0) as log:
                process = subprocess.Popen(
                    command,
                    cwd=str(SCRIPT_DIR),
                    env=env,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    start_new_session=True,
                )
            self.active = {
                "id": action_id,
                "name": action["name"],
                "pgid": process.pid,
                "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                "log": str(log_path),
            }
            self.process = process
            self._save()
            return previous, dict(self.active)

    def current_log(self):
        with self.lock:
            self.status()
            item = self.active or self.last
            if item and Path(item.get("log", "")).is_file():
                return dict(item)
            logs = sorted(LOG_DIR.glob("*.log"), key=lambda path: path.stat().st_mtime, reverse=True)
            if logs:
                return {"name": logs[0].stem, "log": str(logs[0]), "result": "anterior"}
            return None


def read_log_tail(path):
    with Path(path).open("rb") as stream:
        stream.seek(0, os.SEEK_END)
        size = stream.tell()
        stream.seek(max(0, size - MAX_LOG_BYTES))
        data = stream.read(MAX_LOG_BYTES)
    data = ANSI_ESCAPE.sub(b"", data)
    prefix = b"[... salida anterior omitida ...]\n" if size > MAX_LOG_BYTES else b""
    return prefix + data


MANAGER = ProcessManager()
CSRF_TOKEN = secrets.token_urlsafe(32)


def page_html():
    actions = discover_actions()
    buttons = "".join(
        f'<button class="action" data-id="{html.escape(a["id"], quote=True)}">'
        f'<span>{html.escape(a["name"])}</span><small>Iniciar</small></button>'
        for a in actions
    )
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>~/amd64gnu+linux and mock mapper</title>
<style>
:root{{--bg:#f4f7fb;--panel:#ffffff;--line:#d7dfeb;--text:#172033;--muted:#627087;--green:#16855b;--red:#c93f50;--blue:#2869c7}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--text);font:15px system-ui,sans-serif}}
main{{max-width:980px;margin:42px auto;padding:0 20px}} h1{{margin:0 0 7px;font-size:26px}} .sub{{color:var(--muted);margin-bottom:24px}}
.status{{display:flex;gap:14px;align-items:center;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:15px 17px;margin-bottom:20px}}
.dot{{width:11px;height:11px;border-radius:50%;background:#64748b}} .dot.on{{background:var(--green);box-shadow:0 0 12px var(--green)}}
#statusText{{flex:1}} button{{font:inherit;color:var(--text);cursor:pointer}} .stop{{background:transparent;border:1px solid var(--red);color:var(--red);border-radius:8px;padding:8px 13px}} .stop:hover{{background:var(--red);color:#fff}} .stop:disabled{{cursor:not-allowed;opacity:.45;background:transparent;color:var(--red)}}
.finder{{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:14px}}
.finder:focus-within{{border-color:var(--blue);box-shadow:0 0 0 3px rgba(40,105,199,.12)}} .searchIcon{{color:var(--muted);font-size:19px}}
#search{{flex:1;min-width:0;border:0;outline:0;background:transparent;color:var(--text);font:inherit;padding:4px}} #search::placeholder{{color:#8792a5}}
#matchCount{{color:var(--muted);white-space:nowrap;font-size:13px}} #clearSearch{{display:none;border:0;background:transparent;color:var(--muted);font-size:19px;padding:2px 5px;line-height:1}}
#clearSearch.visible{{display:block}} .empty{{display:none;grid-column:1/-1;padding:26px;text-align:center;color:var(--muted);background:var(--panel);border:1px dashed var(--line);border-radius:10px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(275px,1fr));gap:11px}} .action{{display:flex;justify-content:space-between;align-items:center;text-align:left;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:15px;min-height:58px}}
.action:hover{{border-color:var(--blue);transform:translateY(-1px)}} .action.active{{border-color:var(--green)}} small{{color:var(--muted)}} #message{{min-height:25px;margin:14px 2px;color:var(--muted)}}
.console{{margin-top:18px;background:#ffffff;border:1px solid var(--line);border-radius:11px;overflow:hidden}} .console summary{{cursor:pointer;padding:13px 16px;color:var(--green);user-select:none}}
.consolebar{{display:flex;align-items:center;gap:12px;padding:0 16px 10px;color:var(--muted)}} .consolebar span{{flex:1}} .consolebar a{{color:var(--blue)}} .consolebar .stop{{padding:5px 10px}} pre{{margin:0;border-top:1px solid var(--line);background:#f8fafc;padding:16px;min-height:180px;max-height:520px;overflow:auto;white-space:pre-wrap;word-break:break-word;color:#253047;font:13px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace}}
@media(max-width:520px){{main{{margin-top:22px}}.status{{align-items:flex-start;flex-wrap:wrap}}}}
</style></head><body><main>
<h1>~/amd64gnu+linux and mock mapper</h1>
<div class="sub">Una sola aplicación activa · menú generado desde ~/amd64gnu+linux</div>
<div class="status"><span id="dot" class="dot"></span><div id="statusText">Consultando…</div><button class="stop" title="Termina la aplicación activa y todos sus procesos hijos">Matar proceso</button></div>
<div class="finder"><span class="searchIcon" aria-hidden="true">⌕</span><input id="search" type="search" autocomplete="off" spellcheck="false" placeholder="Buscar aplicación…" aria-label="Buscar aplicación"><span id="matchCount"></span><button id="clearSearch" type="button" title="Limpiar búsqueda" aria-label="Limpiar búsqueda">×</button></div>
<div class="grid">{buttons}<p id="empty" class="empty">No hay coincidencias. Prueba con otro nombre.</p></div><div id="message"></div>
<details id="console" class="console"><summary>▸ Ver salida de ejecución</summary><div class="consolebar"><span id="logName">Última salida disponible</span><button class="stop" title="Termina la aplicación activa y todos sus procesos hijos">Matar proceso</button><a href="/api/log?download=1">Descargar .txt</a></div><pre id="logText">Abre esta sección para cargar la salida…</pre></details>
<script>
const token={json.dumps(CSRF_TOKEN)};
const msg=document.querySelector('#message');
const search=document.querySelector('#search');
const actionButtons=[...document.querySelectorAll('.action')];
const normalize=value=>value.toLocaleLowerCase('es').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,' ').trim();
function matchScore(name,query){{
 if(!query)return 0;
 const compactName=name.replace(/ /g,''),compactQuery=query.replace(/ /g,'');
 if(name===query)return 10000;
 if(name.startsWith(query))return 8000-query.length;
 const phrase=name.indexOf(query); if(phrase>=0)return 6000-phrase;
 const words=name.split(' '),terms=query.split(' ').filter(Boolean);
 if(terms.every(term=>words.some(word=>word.startsWith(term))))return 4000-terms.reduce((sum,term)=>sum+Math.min(...words.map(word=>word.indexOf(term)<0?99:word.indexOf(term))),0);
 const compactAt=compactName.indexOf(compactQuery);if(compactAt>=0)return 3000-compactAt;
 let position=0,gaps=0;for(const char of compactQuery){{const found=compactName.indexOf(char,position);if(found<0)return -1;gaps+=found-position;position=found+1}}return 1000-gaps;
}}
function filterActions(){{
 const query=normalize(search.value),matches=[];
 actionButtons.forEach((button,index)=>{{const score=matchScore(normalize(button.textContent.replace('Iniciar','')),query);button.hidden=score<0;if(score>=0)matches.push({{button,score,index}})}});
 matches.sort((a,b)=>b.score-a.score||a.index-b.index).forEach(item=>document.querySelector('.grid').insertBefore(item.button,document.querySelector('#empty')));
 document.querySelector('#empty').style.display=matches.length?'none':'block';
 document.querySelector('#matchCount').textContent=query?`${{matches.length}} coincidencia${{matches.length===1?'':'s'}}`:`${{actionButtons.length}} opciones`;
 document.querySelector('#clearSearch').classList.toggle('visible',!!search.value);
}}
search.addEventListener('input',filterActions);
document.querySelector('#clearSearch').onclick=()=>{{search.value='';filterActions();search.focus()}};
document.addEventListener('keydown',event=>{{if(event.key==='/'&&document.activeElement!==search){{event.preventDefault();search.focus()}}if(event.key==='Escape'&&document.activeElement===search){{search.value='';filterActions();search.blur()}}}});
async function post(path, body={{}}){{
 const r=await fetch(path,{{method:'POST',headers:{{'Content-Type':'application/x-www-form-urlencoded'}},body:new URLSearchParams({{...body,token}})}});
 const data=await r.json(); if(!r.ok) throw new Error(data.error||'Error'); return data;
}}
function paint(active){{
 document.querySelector('#dot').classList.toggle('on',!!active);
 document.querySelector('#statusText').textContent=active ? `Activa: ${{active.name}} · desde ${{active.started_at}}` : 'Ninguna aplicación activa';
 document.querySelectorAll('.action').forEach(b=>b.classList.toggle('active',active&&b.dataset.id===active.id));
 document.querySelectorAll('.stop').forEach(b=>b.disabled=!active);
}}
async function status(){{try{{const r=await fetch('/api/status',{{cache:'no-store'}});paint((await r.json()).active)}}catch(e){{msg.textContent=e.message}}}}
async function loadLog(){{
 if(!document.querySelector('#console').open)return;
 try{{const r=await fetch('/api/log',{{cache:'no-store'}});document.querySelector('#logName').textContent=r.headers.get('X-Log-Name')||'Salida';const pre=document.querySelector('#logText'),atEnd=pre.scrollHeight-pre.scrollTop-pre.clientHeight<45;pre.textContent=await r.text();if(atEnd)pre.scrollTop=pre.scrollHeight}}catch(e){{document.querySelector('#logText').textContent=e.message}}
}}
document.querySelector('#console').addEventListener('toggle',loadLog);
actionButtons.forEach(b=>b.onclick=async()=>{{
 msg.textContent='Cambiando aplicación…'; document.querySelectorAll('button').forEach(x=>x.disabled=true);
 try{{const d=await post('/api/start',{{id:b.dataset.id}});paint(d.active);msg.textContent=d.previous?`Se detuvo ${{d.previous}} y se inició ${{d.active.name}}.`:`Se inició ${{d.active.name}}.`}}catch(e){{msg.textContent=e.message}}finally{{document.querySelectorAll('button').forEach(x=>x.disabled=false)}}
}});
document.querySelectorAll('.stop').forEach(b=>b.onclick=async()=>{{
 if(!confirm('¿Matar la aplicación activa y todos sus procesos hijos?'))return;
 document.querySelectorAll('button').forEach(x=>x.disabled=true);
 try{{const d=await post('/api/stop');paint(null);msg.textContent=d.stopped?`Se detuvo ${{d.stopped}}.`:'No había una aplicación activa.'}}catch(e){{msg.textContent=e.message;await status()}}finally{{document.querySelectorAll('.action').forEach(x=>x.disabled=false)}}
}});
filterActions();status(); setInterval(()=>{{status();loadLog()}},3000);
</script></main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "AssemblyDispatch/1.0"

    def _json(self, status, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            data = page_html().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; frame-ancestors 'none'")
            self.send_header("X-Frame-Options", "DENY")
            self.end_headers()
            self.wfile.write(data)
        elif path == "/api/status":
            self._json(200, {"active": MANAGER.status(), "actions": len(discover_actions())})
        elif path == "/api/log":
            item = MANAGER.current_log()
            download = parse_qs(urlparse(self.path).query).get("download", ["0"])[0] == "1"
            if not item:
                data = b"Todavia no hay salidas de ejecucion.\n"
                name = "sin-salida"
            else:
                name = item.get("name", "salida")
                if download:
                    log_path = Path(item["log"])
                    safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", str(name))
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain; charset=utf-8")
                    self.send_header("Content-Length", str(log_path.stat().st_size))
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("Content-Disposition", f'attachment; filename="{safe_name}.txt"')
                    self.end_headers()
                    with log_path.open("rb") as stream:
                        while True:
                            chunk = stream.read(64 * 1024)
                            if not chunk:
                                break
                            self.wfile.write(chunk)
                    return
                data = read_log_tail(item["log"])
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Log-Name", str(name))
            if download:
                safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", str(name))
                self.send_header("Content-Disposition", f'attachment; filename="{safe_name}.txt"')
            self.end_headers()
            self.wfile.write(data)
        else:
            self._json(404, {"error": "No encontrado"})

    def do_POST(self):
        path = urlparse(self.path).path
        origin = self.headers.get("Origin")
        allowed = {f"http://{HOST}:{PORT}", f"http://localhost:{PORT}"}
        if origin and origin not in allowed:
            self._json(403, {"error": "Origen no permitido"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 4096:
                raise ValueError("Solicitud demasiado grande")
            form = parse_qs(self.rfile.read(length).decode("utf-8"))
            if not secrets.compare_digest(form.get("token", [""])[0], CSRF_TOKEN):
                self._json(403, {"error": "Token inválido; recarga la página"})
                return
            if path == "/api/start":
                previous, active = MANAGER.start(form.get("id", [""])[0])
                self._json(200, {"previous": previous, "active": active})
            elif path == "/api/stop":
                self._json(200, {"stopped": MANAGER.stop(), "active": None})
            else:
                self._json(404, {"error": "No encontrado"})
        except (ValueError, OSError, subprocess.SubprocessError) as exc:
            self._json(400, {"error": str(exc)})

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)

    def shutdown(_signum, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print(f"Assembly Dispatch disponible en http://{HOST}:{PORT}", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        MANAGER.stop()


if __name__ == "__main__":
    main()
