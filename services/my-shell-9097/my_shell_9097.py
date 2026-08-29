#!/usr/bin/env python3
"""Concurrent localhost job runner backed by ~/monoliths-hm/my.shell.sh."""

import html
import json
import os
import re
import secrets
import signal
import subprocess
import threading
import time
import uuid
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HOST, PORT = "127.0.0.1", 9097
HOME = Path("/home/user")
MENU_SCRIPT = HOME / "monoliths-hm" / "my.shell.sh"
STATE_DIR = HOME / ".local" / "state" / "my-shell-9097"
LOG_DIR = STATE_DIR / "logs"
JOBS_FILE = STATE_DIR / "jobs.json"
MAX_VIEW = 512 * 1024
MAX_JOBS = 100
ANSI = re.compile(rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")


def environment():
    env = os.environ.copy()
    env.update({
        "HOME": str(HOME), "USER": "user", "LOGNAME": "user",
        "DISPLAY": env.get("DISPLAY", ":0"),
        "XAUTHORITY": env.get("XAUTHORITY", str(HOME / ".Xauthority")),
    })
    return env


def menu_items():
    try:
        result = subprocess.run(
            ["/bin/dash", str(MENU_SCRIPT)], cwd=str(HOME), env=environment(),
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, timeout=15, check=False, text=True,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    items = []
    pattern = re.compile(r"^\s*([0-9]+)\)\s*(.+?)\s*$")
    for line in result.stdout.splitlines():
        match = pattern.match(line)
        if match:
            parts = re.split(r"\s+-\s+", match.group(2), maxsplit=1)
            name = parts[0].strip()
            description = (parts[1] if len(parts) == 2 else name).strip()
            items.append({"id": match.group(1), "name": name, "description": description})
    return items


class Jobs:
    def __init__(self):
        self.lock = threading.RLock()
        self.jobs = OrderedDict()
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        try:
            saved = json.loads(JOBS_FILE.read_text(encoding="utf-8"))
            for job in saved[-MAX_JOBS:]:
                if Path(job.get("log", "")).is_file():
                    if job.get("status") == "running":
                        job.update(status="interrupted", ended_at=time.strftime("%Y-%m-%d %H:%M:%S"))
                    self.jobs[job["id"]] = job
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            pass

    def save(self):
        data = [self.public(job) for job in self.jobs.values()]
        temporary = JOBS_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        temporary.replace(JOBS_FILE)

    @staticmethod
    def group_alive(pgid):
        try:
            os.killpg(pgid, 0)
            return True
        except (ProcessLookupError, PermissionError):
            return False

    def refresh(self):
        with self.lock:
            changed = False
            for job in self.jobs.values():
                process = job.pop("_process", None)
                if process is not None:
                    code = process.poll()
                    if code is None:
                        job["_process"] = process
                    else:
                        job["exit_code"] = code
                if job["status"] == "running" and not self.group_alive(job["pgid"]):
                    job["status"] = "finished" if job.get("exit_code", 0) == 0 else "failed"
                    job["ended_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
                    changed = True
            if changed:
                self.save()
            return [self.public(j) for j in reversed(self.jobs.values())]

    @staticmethod
    def public(job):
        return {k: v for k, v in job.items() if not k.startswith("_")}

    def start(self, title, command, kind):
        with self.lock:
            job_id = uuid.uuid4().hex[:12]
            stamp = time.strftime("%Y%m%d-%H%M%S")
            log_path = LOG_DIR / f"{stamp}-{job_id}.log"
            with log_path.open("ab", buffering=0) as log:
                process = subprocess.Popen(
                    command, cwd=str(HOME), env=environment(), stdin=subprocess.DEVNULL,
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                )
            job = {
                "id": job_id, "title": title, "kind": kind, "command": command,
                "pgid": process.pid, "status": "running", "exit_code": None,
                "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                "ended_at": None, "log": str(log_path), "_process": process,
            }
            self.jobs[job_id] = job
            while len(self.jobs) > MAX_JOBS:
                oldest_id, oldest = next(iter(self.jobs.items()))
                if oldest["status"] == "running":
                    break
                self.jobs.pop(oldest_id)
            self.save()
            return self.public(job)

    def start_menu(self, option_id):
        option = next((item for item in menu_items() if item["id"] == option_id), None)
        if not option:
            raise ValueError("La opción ya no existe en my.shell.sh")
        return self.start(option["name"], ["/bin/dash", str(MENU_SCRIPT), "-q", option_id], "menu")

    def start_command(self, text):
        text = text.strip()
        if not text:
            raise ValueError("Escribe un comando")
        if len(text) > 4096:
            raise ValueError("El comando es demasiado largo")
        return self.start(text, ["/bin/bash", "-lc", text], "command")

    def kill(self, job_id):
        with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                raise ValueError("Trabajo desconocido")
            if job["status"] != "running":
                return self.public(job)
            try:
                os.killpg(job["pgid"], signal.SIGTERM)
            except ProcessLookupError:
                pass
            deadline = time.monotonic() + 5
            while self.group_alive(job["pgid"]) and time.monotonic() < deadline:
                process = job.get("_process")
                if process:
                    process.poll()
                time.sleep(.1)
            if self.group_alive(job["pgid"]):
                try:
                    os.killpg(job["pgid"], signal.SIGKILL)
                except ProcessLookupError:
                    pass
            process = job.pop("_process", None)
            if process:
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    pass
            job.update(status="killed", ended_at=time.strftime("%Y-%m-%d %H:%M:%S"))
            self.save()
            return self.public(job)

    def get(self, job_id):
        with self.lock:
            return self.jobs.get(job_id)

    def clear_history(self):
        with self.lock:
            removed = []
            for job_id, job in list(self.jobs.items()):
                if job["status"] == "running":
                    continue
                removed.append(self.jobs.pop(job_id))
            self.save()
        for job in removed:
            try:
                Path(job["log"]).unlink()
            except FileNotFoundError:
                pass
        return len(removed)

    def stop_all(self):
        for job in self.refresh():
            if job["status"] == "running":
                try:
                    self.kill(job["id"])
                except (ValueError, OSError):
                    pass


JOBS = Jobs()
TOKEN = secrets.token_urlsafe(32)


def tail(path, limit=MAX_VIEW):
    with Path(path).open("rb") as stream:
        stream.seek(0, os.SEEK_END)
        size = stream.tell()
        stream.seek(max(0, size - limit))
        data = stream.read(limit)
    return (b"[... salida anterior omitida ...]\n" if size > limit else b"") + ANSI.sub(b"", data)


def page():
    cards = "".join(
        '<button class="option" data-id="%s" data-search="%s"><b>%s</b><span>#%s · %s</span></button>' % (
            html.escape(item["id"], quote=True),
            html.escape((item["name"] + " " + item["description"]).lower(), quote=True),
            html.escape(item["name"]), html.escape(item["id"]), html.escape(item["description"]),
        ) for item in menu_items()
    )
    return f"""<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>~/monoliths-hm/my.shell.sh mapper</title><style>
:root{{--bg:#f4f7fb;--panel:#fff;--line:#d6dfeb;--text:#172033;--muted:#637188;--green:#16855b;--red:#c43e4f;--blue:#2869c7}}*{{box-sizing:border-box}}
body{{margin:0;background:var(--bg);color:var(--text);font:15px system-ui,sans-serif}}main{{max-width:1180px;margin:35px auto;padding:0 20px}}h1{{margin:0 0 5px;font-size:25px}}.sub{{color:var(--muted);margin-bottom:20px}}
.terminal,.job{{background:var(--panel);border:1px solid var(--line);border-radius:11px}}.terminal{{padding:16px;margin-bottom:18px}}.terminal form{{display:flex;gap:9px}}input{{width:100%;padding:11px 12px;border:1px solid var(--line);border-radius:8px;font:14px ui-monospace,monospace}}button{{color:var(--text);font:inherit;cursor:pointer}}
.run{{border:0;border-radius:8px;background:var(--blue);color:#fff;padding:0 18px}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:9px;max-height:430px;overflow:auto;padding:2px}}
.option{{display:flex;flex-direction:column;gap:5px;text-align:left;background:#fff;border:1px solid var(--line);border-radius:9px;padding:12px}}.option[hidden]{{display:none}}.option:hover{{border-color:var(--blue)}}.option span{{color:var(--muted);font-size:12px}}
h2{{font-size:19px;margin:0}}.history-head{{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-top:25px}}.clear{{display:inline-flex;align-items:center;gap:7px;border:1px solid var(--red);color:var(--red);background:#fff;border-radius:7px;padding:7px 10px}}.clear:hover{{background:#fff5f6}}.clear:disabled{{cursor:not-allowed;opacity:.55}}.clear svg{{width:16px;height:16px;fill:currentColor}}.jobs{{display:grid;gap:12px;margin-top:12px}}.jobhead{{display:flex;gap:12px;align-items:center;padding:13px 15px}}.jobtitle{{flex:1;min-width:0;overflow-wrap:anywhere}}.badge{{font-size:12px;padding:4px 8px;border-radius:20px;background:#edf1f6}}.running{{background:#e4f7ef;color:#08704a}}.failed,.killed{{background:#fdebed;color:#a62738}}.kill{{border:1px solid var(--red);color:var(--red);background:#fff;border-radius:7px;padding:6px 10px}}
.job details{{border-top:1px solid var(--line)}}summary{{padding:11px 15px;cursor:pointer;color:var(--green)}}pre{{margin:0;background:#f8fafc;border-top:1px solid var(--line);padding:14px;max-height:420px;min-height:90px;overflow:auto;white-space:pre-wrap;word-break:break-word;font:13px/1.5 ui-monospace,monospace}}.download{{float:right;color:var(--blue)}}
@media(max-width:600px){{main{{margin-top:20px}}.terminal form{{flex-direction:column}}.run{{padding:10px}}.jobhead{{align-items:flex-start;flex-wrap:wrap}}}}
</style></head><body><main><h1>~/monoliths-hm/my.shell.sh mapper</h1><div class="sub">localhost:9097 · ejecuciones independientes y concurrentes</div>
<section class="terminal"><b>Buscar o ejecutar</b><p style="color:var(--muted);margin:6px 0 12px">Escribe para filtrar las instrucciones mapeadas. Pulsa Enter para ejecutar el texto como comando en /home/user.</p><form id="commandForm"><input id="command" autocomplete="off" placeholder="Busca una instrucción o escribe un comando, por ejemplo: emacs -mm" autofocus><button class="run">Ejecutar</button></form></section>
<section class="grid">{cards}</section>
<div class="history-head"><h2>Ejecuciones</h2><button id="clearHistory" class="clear" type="button" title="Limpiar historial"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 3h6l1 2h4v2H4V5h4l1-2Zm-2 6h10l-1 12H8L7 9Zm3 2v8h2v-8h-2Zm4 0v8h2v-8h-2Z"/></svg><span>Limpiar historial</span></button></div><section id="jobs" class="jobs"><p style="color:var(--muted)">Todavía no hay ejecuciones.</p></section>
<script>const token={json.dumps(TOKEN)};let snapshot='';
async function post(path,data){{const r=await fetch(path,{{method:'POST',headers:{{'Content-Type':'application/x-www-form-urlencoded'}},body:new URLSearchParams({{...data,token}})}}),j=await r.json();if(!r.ok)throw Error(j.error||'Error');return j}}
const commandInput=document.querySelector('#command');
commandInput.oninput=e=>{{const q=e.target.value.trim().toLowerCase();document.querySelectorAll('.option').forEach(b=>b.hidden=!!q&&!b.dataset.search.includes(q))}};
document.querySelectorAll('.option').forEach(b=>b.onclick=async()=>{{b.disabled=true;try{{await post('/api/menu',{{id:b.dataset.id}});await update()}}catch(e){{alert(e.message)}}finally{{b.disabled=false}}}});
document.querySelector('#commandForm').onsubmit=async e=>{{e.preventDefault();const input=commandInput;try{{await post('/api/command',{{command:input.value}});input.value='';input.dispatchEvent(new Event('input'));await update()}}catch(x){{alert(x.message)}}}};
document.querySelector('#clearHistory').onclick=async e=>{{if(!confirm('¿Borrar del historial todas las ejecuciones terminadas y sus archivos de salida?'))return;const button=e.currentTarget;button.disabled=true;try{{const result=await post('/api/history/clear',{{}});snapshot='';await update();alert(result.removed?`Se borraron ${{result.removed}} ejecuciones del historial.`:'No hay ejecuciones terminadas para borrar.')}}catch(x){{alert(x.message)}}finally{{button.disabled=false}}}};
function esc(s){{return String(s).replace(/[&<>\"']/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}}[c]))}}
function paintLogs(jobs){{const byId=new Map(jobs.map(j=>[j.id,j.output||'']));document.querySelectorAll('.job details[open]').forEach(d=>{{const pre=d.querySelector('pre'),atEnd=pre.scrollHeight-pre.scrollTop-pre.clientHeight<40;pre.textContent=byId.get(d.closest('.job').dataset.id)||'(sin salida)';if(atEnd)pre.scrollTop=pre.scrollHeight}})}}
async function update(){{const data=await (await fetch('/api/jobs',{{cache:'no-store'}})).json(),key=JSON.stringify(data.jobs.map(j=>[j.id,j.status,j.exit_code]));if(key===snapshot){{paintLogs(data.jobs);return}}snapshot=key;const box=document.querySelector('#jobs');box.innerHTML=data.jobs.length?'':'<p>Todavía no hay ejecuciones.</p>';data.jobs.forEach(j=>{{const el=document.createElement('article');el.className='job';el.dataset.id=j.id;el.innerHTML=`<div class="jobhead"><span class="badge ${{j.status}}">${{esc(j.status)}}</span><div class="jobtitle"><b>${{esc(j.title)}}</b><div style="color:var(--muted);font-size:12px">PID ${{j.pgid}} · ${{esc(j.started_at)}}${{j.exit_code===null?'':' · salida '+j.exit_code}}</div></div><button class="kill">Matar proceso</button></div><details><summary>Ver salida <a class="download" href="/api/log?id=${{j.id}}&download=1">Descargar .txt</a></summary><pre>${{esc(j.output||'(sin salida)')}}</pre></details>`;const kill=el.querySelector('.kill');kill.onclick=async()=>{{if(confirm('¿Matar este proceso y sus hijos?')){{const result=await post('/api/kill',{{id:j.id}});if(result.job.status!=='killed')alert('El proceso ya había finalizado; no quedaba nada que matar.');await update()}}}};el.querySelector('details').ontoggle=()=>paintLogs(data.jobs);box.appendChild(el)}});paintLogs(data.jobs)}}
update();setInterval(update,2500);</script></main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def send_json(self, code, value):
        data = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.send_header("Cache-Control", "no-store"); self.end_headers(); self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            data = page().encode(); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.send_header("Cache-Control", "no-store"); self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; frame-ancestors 'none'"); self.end_headers(); self.wfile.write(data)
        elif parsed.path == "/api/jobs":
            jobs = JOBS.refresh()
            for job in jobs:
                try:
                    job["output"] = tail(job["log"], 64 * 1024).decode("utf-8", "replace")
                except OSError:
                    job["output"] = "(archivo de salida no disponible)"
            self.send_json(200, {"jobs": jobs})
        elif parsed.path == "/api/log":
            query = parse_qs(parsed.query); job = JOBS.get(query.get("id", [""])[0])
            if not job: self.send_json(404, {"error": "Trabajo desconocido"}); return
            path = Path(job["log"]); download = query.get("download", ["0"])[0] == "1"
            if download:
                self.send_response(200); self.send_header("Content-Type", "text/plain; charset=utf-8"); self.send_header("Content-Length", str(path.stat().st_size)); self.send_header("Content-Disposition", f'attachment; filename="{job["id"]}.txt"'); self.end_headers()
                with path.open("rb") as stream:
                    while True:
                        chunk=stream.read(65536)
                        if not chunk: break
                        self.wfile.write(chunk)
            else:
                data=tail(path); self.send_response(200); self.send_header("Content-Type", "text/plain; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.send_header("Cache-Control", "no-store"); self.end_headers(); self.wfile.write(data)
        else: self.send_json(404, {"error": "No encontrado"})

    def do_POST(self):
        parsed=urlparse(self.path); origin=self.headers.get("Origin")
        if origin and origin not in {f"http://{HOST}:{PORT}",f"http://localhost:{PORT}"}: self.send_json(403,{"error":"Origen no permitido"}); return
        try:
            length=int(self.headers.get("Content-Length","0"))
            if length>8192: raise ValueError("Solicitud demasiado grande")
            form=parse_qs(self.rfile.read(length).decode())
            if not secrets.compare_digest(form.get("token",[""])[0],TOKEN): self.send_json(403,{"error":"Token inválido; recarga la página"}); return
            if parsed.path=="/api/menu": job=JOBS.start_menu(form.get("id",[""])[0])
            elif parsed.path=="/api/command": job=JOBS.start_command(form.get("command",[""])[0])
            elif parsed.path=="/api/kill": job=JOBS.kill(form.get("id",[""])[0])
            elif parsed.path=="/api/history/clear": self.send_json(200,{"removed":JOBS.clear_history()}); return
            else: self.send_json(404,{"error":"No encontrado"}); return
            self.send_json(200,{"job":job})
        except (ValueError,OSError,subprocess.SubprocessError) as exc: self.send_json(400,{"error":str(exc)})

    def log_message(self, fmt, *args): print("%s - %s"%(self.address_string(),fmt%args),flush=True)


def main():
    server=ThreadingHTTPServer((HOST,PORT),Handler)
    def shutdown(_sig,_frame): threading.Thread(target=server.shutdown,daemon=True).start()
    signal.signal(signal.SIGTERM,shutdown); signal.signal(signal.SIGINT,shutdown)
    print(f"my.shell mapper disponible en http://{HOST}:{PORT}",flush=True)
    try: server.serve_forever()
    finally: server.server_close(); JOBS.stop_all()


if __name__=="__main__": main()
