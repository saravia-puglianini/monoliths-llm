#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
registro-diario-lucid.py - Interfaz de registro diario con estética Lucid / Motif / X11
Estilo visual clásico, ligero y nítido (3D bevels, paleta Lucid, alto contraste)
"""
import base64
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
import html
import subprocess
import shutil
import tempfile
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from PIL import Image

def html_escape(text):
    return html.escape(str(text or ""))

CONFIG = os.path.expanduser("~/.justificar/jira_config")
CSV = os.path.expanduser("~/.justificar/justificar.csv")
STATE_FILE = os.path.expanduser("~/.justificar/registro-diario-yad.json")
LOG_FILE = os.path.expanduser("~/.justificar/registro-diario-lucid.log")


def setup_logging():
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logger = logging.getLogger("registro-diario-lucid")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        handler = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3, encoding="utf-8")
        handler.setFormatter(logging.Formatter("%(asctime)s | %(levelname)s | %(message)s"))
        logger.addHandler(handler)
    return logger


LOG = setup_logging()


def read_config():
    values = {}
    with open(CONFIG, encoding="utf-8") as handle:
        for raw in handle:
            if "=" not in raw or raw.lstrip().startswith("#"):
                continue
            key, value = raw.split("=", 1)
            values[key.strip()] = value.strip().strip('"\'')
    missing = [key for key in ("JIRA_DOMAIN", "JIRA_EMAIL", "JIRA_API_TOKEN") if not values.get(key)]
    if missing:
        raise RuntimeError("Faltan datos en ~/.justificar/jira_config: " + ", ".join(missing))
    return values


def jira(config, path, method="GET", payload=None, timeout=15):
    url = config.get("_API_BASE", config["JIRA_DOMAIN"]).rstrip("/") + path
    token = base64.b64encode(f'{config["JIRA_EMAIL"]}:{config["JIRA_API_TOKEN"]}'.encode()).decode()
    body = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=body, method=method, headers={
        "Authorization": f"Basic {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        try:
            detail = json.loads(detail).get("errorMessages", [detail])[0]
        except (json.JSONDecodeError, IndexError, TypeError):
            pass
        raise RuntimeError(f"Jira respondió {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"No se pudo conectar con Jira: {error.reason}") from error


def configure_api_base(config):
    """Usa automáticamente la ruta clásica o la ruta de tokens con alcance."""
    if config.get("_ACCOUNT_ID"):
        return
    config.pop("_API_BASE", None)
    try:
        me = jira(config, "/rest/api/3/myself")
        config["_ACCOUNT_ID"] = me.get("accountId")
        LOG.info("Autenticación Jira correcta mediante endpoint clásico")
        return
    except RuntimeError as error:
        if "401" not in str(error):
            raise
    tenant_url = config["JIRA_DOMAIN"].rstrip("/") + "/_edge/tenant_info"
    try:
        with urllib.request.urlopen(tenant_url, timeout=15) as response:
            cloud_id = json.loads(response.read().decode()).get("cloudId")
    except (urllib.error.URLError, json.JSONDecodeError) as error:
        raise RuntimeError("No se pudo obtener el cloudId de Jira para usar el token con alcance.") from error
    if not cloud_id:
        raise RuntimeError("Jira no devolvió un cloudId válido.")
    config["_API_BASE"] = f"https://api.atlassian.com/ex/jira/{cloud_id}"
    me = jira(config, "/rest/api/3/myself")
    config["_ACCOUNT_ID"] = me.get("accountId")
    LOG.info("Autenticación Jira correcta mediante endpoint para token con alcance")


def get_issues(config):
    configure_api_base(config)
    
    # 1. Consulta de tareas asignadas o con worklogs del usuario actual
    jql_tasks = ('(assignee = currentUser() OR worklogAuthor = currentUser()) '
                 'AND (statusCategory != Done OR status = "En medición" OR sprint in openSprints()) '
                 'AND issuetype in (Task, Tarea, "Sub-task", Subtarea, Correctivos, "Error en producción", Incidencias) '
                 'ORDER BY updated DESC')
    
    # 2. Consulta de todas las Historias de usuario del sprint activo y activas
    jql_stories = ('sprint in openSprints() AND issuetype in (Story, "Historia de usuario", Historia, Hito) '
                   'ORDER BY key ASC')
    jql_stories_fallback = ('(statusCategory != Done OR updated >= -30d) '
                            'AND issuetype in (Story, "Historia de usuario", Historia, Hito) '
                            'ORDER BY updated DESC')

    query_tasks = urllib.parse.urlencode({
        "jql": jql_tasks,
        "maxResults": 100,
        "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks",
    })
    query_stories = urllib.parse.urlencode({
        "jql": jql_stories,
        "maxResults": 200,
        "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks",
    })
    query_stories_fallback = urllib.parse.urlencode({
        "jql": jql_stories_fallback,
        "maxResults": 100,
        "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks",
    })

    result_tasks = jira(config, "/rest/api/3/search/jql?" + query_tasks)
    result_stories = jira(config, "/rest/api/3/search/jql?" + query_stories)
    result_stories_fb = jira(config, "/rest/api/3/search/jql?" + query_stories_fallback)

    all_raw_issues = []
    seen_keys = set()

    for res in (result_tasks, result_stories, result_stories_fb):
        for issue in res.get("issues", []):
            k = issue.get("key")
            if k and k not in seen_keys:
                seen_keys.add(k)
                all_raw_issues.append(issue)

    rows = []
    story_to_tasks_map = {}
    task_to_stories_map = {}

    for issue in all_raw_issues:
        issue_key = issue.get("key", "")
        fields = issue.get("fields", {})
        itype = (fields.get("issuetype") or {}).get("name", "Tarea")
        is_story = itype in ("Historia de usuario", "Story", "Historia") or ("HU" in str(fields.get("summary", "")))

        for link in fields.get("issuelinks", []):
            inward = link.get("inwardIssue") or {}
            outward = link.get("outwardIssue") or {}
            for other in (inward, outward):
                if not other:
                    continue
                o_key = other.get("key")
                o_type = (other.get("fields") or {}).get("issuetype", {}).get("name", "")
                o_is_story = o_type in ("Historia de usuario", "Story", "Historia") or ("HU" in str((other.get("fields") or {}).get("summary", "")))

                if is_story and not o_is_story and o_key:
                    story_to_tasks_map.setdefault(issue_key, set()).add(o_key)
                    task_to_stories_map.setdefault(o_key, set()).add(issue_key)
                elif not is_story and o_is_story and o_key:
                    task_to_stories_map.setdefault(issue_key, set()).add(o_key)
                    story_to_tasks_map.setdefault(o_key, set()).add(issue_key)

    for issue in all_raw_issues:
        issue_key = issue.get("key", "")
        fields = issue.get("fields", {})
        project = fields.get("project") or {}
        parent = fields.get("parent") or {}
        parent_fields = parent.get("fields") or {}
        seconds = fields.get("timespent") or fields.get("aggregatetimespent") or 0
        itype = (fields.get("issuetype") or {}).get("name", "Tarea")

        linked_stories = list(task_to_stories_map.get(issue_key, set()))
        linked_tasks = list(story_to_tasks_map.get(issue_key, set()))

        rows.append({
            "key": issue_key,
            "project": project.get("name", "-"),
            "project_key": project.get("key", ""),
            "project_id": project.get("id", ""),
            "parent_key": parent.get("key", "-"),
            "parent": parent_fields.get("summary", "-"),
            "summary": fields.get("summary", "Sin título"),
            "status": (fields.get("status") or {}).get("name", "Sin estado"),
            "hours": f"{seconds / 3600:g} h",
            "type": itype,
            "linked_stories": linked_stories,
            "linked_tasks": linked_tasks,
        })
    LOG.info("Consulta completada: %s registros (%s tareas asignadas, %s historias disponibles)", len(rows), len(result_tasks.get("issues", [])), len(result_stories.get("issues", [])))
    return rows


def create_task_for_story(config, story_issue, activity, description):
    """Crea una tarea en Jira asociada a la Historia y a su épica parent con el título de la actividad."""
    configure_api_base(config)
    project_key = story_issue.get("project_key") or story_issue.get("key", "").split("-")[0]
    parent_key = story_issue.get("parent_key")
    summary = f"{activity}: {description}" if description and description != activity else f"{activity} - {story_issue.get('summary', '')}"

    payload = {
        "fields": {
            "project": {"key": project_key},
            "summary": summary,
            "issuetype": {"name": "Tarea"},
            "description": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [
                            {"type": "text", "text": f"Registro de {activity} para la historia {story_issue.get('key')}: {story_issue.get('summary')}"}
                        ]
                    }
                ]
            }
        }
    }
    if parent_key and parent_key != "-":
        payload["fields"]["parent"] = {"key": parent_key}

    account_id = config.get("_ACCOUNT_ID")
    if account_id:
        payload["fields"]["assignee"] = {"accountId": account_id}

    created = jira(config, "/rest/api/3/issue", "POST", payload)
    new_task_key = created.get("key", "")

    if new_task_key and story_issue.get("key"):
        try:
            jira(config, "/rest/api/3/issueLink", "POST", {
                "type": {"name": "Historia/Hitos"},
                "inwardIssue": {"key": story_issue.get("key")},
                "outwardIssue": {"key": new_task_key}
            })
        except Exception:
            try:
                jira(config, "/rest/api/3/issueLink", "POST", {
                    "type": {"name": "Relates"},
                    "inwardIssue": {"key": story_issue.get("key")},
                    "outwardIssue": {"key": new_task_key}
                })
            except Exception as e:
                LOG.warning("No se pudo crear el enlace issueLink: %s", e)

    return new_task_key, summary


def get_jira_worklogs(config, selected_day):
    """Obtiene los worklogs reales del usuario autenticado para una fecha con su historia asociada."""
    configure_api_base(config)
    account_id = config.get("_ACCOUNT_ID")
    jql = f'worklogAuthor = currentUser() AND worklogDate = "{selected_day}" ORDER BY updated DESC'
    query = urllib.parse.urlencode({"jql": jql, "maxResults": 100, "fields": "key,summary,issuetype,parent,issuelinks"})
    found = jira(config, "/rest/api/3/search/jql?" + query, timeout=15)
    issues_list = found.get("issues", [])
    if not issues_list:
        return []

    def fetch_worklogs_for_issue(issue):
        issue_key = issue.get("key", "")
        fields = issue.get("fields") or {}
        summary = fields.get("summary", "")
        parent_summary = (fields.get("parent") or {}).get("fields", {}).get("summary", "—")

        story_label = "—"
        for link in fields.get("issuelinks", []):
            for other in (link.get("inwardIssue"), link.get("outwardIssue")):
                if not other:
                    continue
                o_fields = other.get("fields") or {}
                o_type = (o_fields.get("issuetype") or {}).get("name", "")
                o_sum = o_fields.get("summary", "")
                if o_type in ("Historia de usuario", "Story", "Historia") or "HU" in o_sum:
                    story_label = f"{other.get('key')}: {o_sum}"
                    break
            if story_label != "—":
                break

        if story_label == "—" and parent_summary != "—":
            story_label = parent_summary

        try:
            data = jira(config, f'/rest/api/3/issue/{urllib.parse.quote(issue_key)}/worklog?maxResults=5000', timeout=10)
            items = []
            for item in data.get("worklogs", []):
                if account_id and (item.get("author") or {}).get("accountId") != account_id:
                    continue
                if str(item.get("started", ""))[:10] != selected_day:
                    continue
                
                comment = item.get("comment", "")
                if isinstance(comment, dict):
                    try:
                        comment = comment.get("content", [{}])[0].get("content", [{}])[0].get("text", "")
                    except Exception:
                        comment = ""

                items.append({
                    "key": issue_key,
                    "summary": summary,
                    "story": story_label,
                    "hours": (item.get("timeSpentSeconds") or 0) / 3600,
                    "activity": comment or "Trabajo en tarea",
                    "worklog_id": str(item.get("id", "")),
                })
            return items
        except Exception as err:
            LOG.warning("No se pudieron cargar worklogs para %s: %s", issue_key, err)
            return []

    records = []
    with ThreadPoolExecutor(max_workers=min(8, len(issues_list))) as executor:
        for res in executor.map(fetch_worklogs_for_issue, issues_list):
            records.extend(res)

    LOG.info("Consulta de worklogs para %s: %s registros, %.2f horas", selected_day, len(records), sum(item["hours"] for item in records))
    return records


def time_spent(hours):
    minutes = round(hours * 60)
    return f"{minutes // 60}h" if minutes % 60 == 0 else f"{minutes}m"


def register_in_jira(config, issue_key, hours, activity, description):
    comment = description if activity == "Trabajo en tarea" else f"{activity}: {description}"
    result = jira(config, f'/rest/api/2/issue/{urllib.parse.quote(issue_key)}/worklog', "POST", {
        "timeSpent": time_spent(hours), "comment": comment,
    })
    worklog_id = str(result.get("id", ""))
    url = (f'{config["JIRA_DOMAIN"].rstrip("/")}/browse/{issue_key}'
           f'?focusedWorklogId={worklog_id}&page=com.atlassian.jira.plugin.system.issuetabpanels:worklog-tabpanel#worklog-{worklog_id}')
    os.makedirs(os.path.dirname(CSV), exist_ok=True)
    hour_label = datetime.now().strftime("%I%p").lstrip("0").lower()
    clean_comment = comment.replace(";", ",").replace("\n", " ")
    with open(CSV, "a", encoding="utf-8") as handle:
        handle.write(f"{date.today().isoformat()};{hour_label};{issue_key};{clean_comment};{url}\n")
    return url


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {"days": {}}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    temporary = STATE_FILE + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(state, handle, ensure_ascii=False, indent=2)
    os.replace(temporary, STATE_FILE)


def day_state(state, day):
    current = state.setdefault("days", {}).setdefault(day, {"selected": 1.0, "unit": "Horas", "activity": "Trabajo en tarea", "worklogs": []})
    current.setdefault("unit", "Horas")
    return current


def format_hours(value):
    try:
        value = float(value)
    except (TypeError, ValueError):
        return "0 h"
    hours = int(value)
    minutes = round((value - hours) * 60)
    if minutes:
        return f"{hours} h {minutes} min" if hours else f"{minutes} min"
    return f"{hours} h"


def format_date_es(iso_date_str):
    try:
        d = datetime.strptime(iso_date_str, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return iso_date_str
    days_es = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    months_es = [
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
    ]
    day_name = days_es[d.weekday()]
    month_name = months_es[d.month - 1]
    return f"{day_name}, {d.day} de {month_name} de {d.year}"


def generate_pdf_in_background(config, selected_day, jira_worklogs=None):
    """Genera PDF en background con capturas completas de las pestañas de worklogs."""
    LOG.info("Iniciando servicio en background para PDF de la fecha: %s", selected_day)
    if not jira_worklogs:
        jira_worklogs = get_jira_worklogs(config, selected_day)

    if not jira_worklogs:
        LOG.warning("No hay registros de worklogs en Jira para %s, no se genera PDF", selected_day)
        return

    downloads_dir = os.path.expanduser("~/Downloads")
    os.makedirs(downloads_dir, exist_ok=True)
    save_path = os.path.join(downloads_dir, f"Registro_Horas_{selected_day}.pdf")

    temp_dir = tempfile.mkdtemp(prefix="jira_screens_")
    try:
        chrome_user_dir = os.path.expanduser("~/.config/google-chrome")
        tmp_profile = os.path.join(temp_dir, "chrome_profile")
        default_src = os.path.join(chrome_user_dir, "Default")
        default_dst = os.path.join(tmp_profile, "Default")
        os.makedirs(default_dst, exist_ok=True)
        for item_name in ["Cookies", "Network", "Local Storage", "Session Storage", "Preferences"]:
            s_p = os.path.join(default_src, item_name)
            d_p = os.path.join(default_dst, item_name)
            if os.path.isdir(s_p):
                shutil.copytree(s_p, d_p, dirs_exist_ok=True)
            elif os.path.isfile(s_p):
                shutil.copy2(s_p, d_p)

        domain = config.get("JIRA_DOMAIN", "").rstrip("/")
        captured_images = []

        def capture_jira_tab(url, out_path):
            import socket

            port = 9222
            cmd = [
                "google-chrome-stable",
                "--headless=new",
                "--disable-gpu",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--window-size=1600,1000",
                f"--remote-debugging-port={port}",
                f"--user-data-dir={tmp_profile}",
                "about:blank"
            ]
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                tab_ws_url = None
                for _ in range(40):
                    time.sleep(0.2)
                    try:
                        req = urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=2)
                        targets = json.loads(req.read().decode())
                        for t in targets:
                            if t.get("type") == "page" and t.get("webSocketDebuggerUrl"):
                                tab_ws_url = t.get("webSocketDebuggerUrl")
                                break
                        if tab_ws_url:
                            break
                    except Exception:
                        pass

                if not tab_ws_url:
                    fallback_cmd = [
                        "google-chrome-stable",
                        "--headless=new",
                        "--disable-gpu",
                        "--no-sandbox",
                        "--disable-dev-shm-usage",
                        "--window-size=1600,1000",
                        "--virtual-time-budget=10000",
                        f"--user-data-dir={tmp_profile}",
                        f"--screenshot={out_path}",
                        url
                    ]
                    subprocess.run(fallback_cmd, capture_output=True, timeout=30)
                    return

                parsed = urllib.parse.urlparse(tab_ws_url)
                host = parsed.hostname or "127.0.0.1"
                ws_port = parsed.port or port
                path = parsed.path

                sock = socket.create_connection((host, ws_port), timeout=10)
                sec_key = base64.b64encode(os.urandom(16)).decode()
                handshake = (
                    f"GET {path} HTTP/1.1\r\n"
                    f"Host: {host}:{ws_port}\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Key: {sec_key}\r\n"
                    "Sec-WebSocket-Version: 13\r\n\r\n"
                )
                sock.sendall(handshake.encode())
                res = sock.recv(4096)
                if b"101" not in res:
                    raise RuntimeError("Fallo de handshake WebSocket CDP")

                msg_id = 1
                def send_cdp(method, params=None):
                    nonlocal msg_id
                    msg_id += 1
                    payload = json.dumps({"id": msg_id, "method": method, "params": params or {}}).encode("utf-8")
                    frame = bytearray([0x81])
                    length = len(payload)
                    mask_key = os.urandom(4)
                    if length <= 125:
                        frame.append(0x80 | length)
                    elif length <= 65535:
                        frame.append(0x80 | 126)
                        frame.extend(length.to_bytes(2, "big"))
                    else:
                        frame.append(0x80 | 127)
                        frame.extend(length.to_bytes(8, "big"))
                    frame.extend(mask_key)
                    masked = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
                    frame.extend(masked)
                    sock.sendall(frame)
                    return msg_id

                def recv_cdp_until(target_id, timeout=15):
                    sock.settimeout(timeout)
                    buf = bytearray()
                    start_t = time.time()
                    while time.time() - start_t < timeout:
                        chunk = sock.recv(65536)
                        if not chunk:
                            break
                        buf.extend(chunk)
                        while len(buf) >= 2:
                            payload_len = buf[1] & 0x7F
                            offset = 2
                            if payload_len == 126:
                                if len(buf) < 4:
                                    break
                                payload_len = int.from_bytes(buf[2:4], "big")
                                offset = 4
                            elif payload_len == 127:
                                if len(buf) < 10:
                                    break
                                payload_len = int.from_bytes(buf[2:10], "big")
                                offset = 10

                            if len(buf) < offset + payload_len:
                                break

                            data = buf[offset:offset+payload_len]
                            buf = buf[offset+payload_len:]
                            try:
                                obj = json.loads(data.decode("utf-8", errors="ignore"))
                                if obj.get("id") == target_id:
                                    return obj
                            except Exception:
                                pass
                    return None

                send_cdp("Page.enable")
                send_cdp("Page.navigate", {"url": url})
                time.sleep(4)

                click_js = """
                (() => {
                    const buttons = Array.from(document.querySelectorAll('button, [role="tab"], a'));
                    const worklogBtn = buttons.find(b => {
                        const t = (b.textContent || '').toLowerCase();
                        return t.includes('registro de trabajo') || t.includes('registro de horas') || t.includes('worklog') || t.includes('trabajo');
                    });
                    if (worklogBtn) {
                        worklogBtn.click();
                        return 'CLICKED_WORKLOG_TAB';
                    }
                    return 'NOT_FOUND';
                })()
                """
                eval_id = send_cdp("Runtime.evaluate", {"expression": click_js})
                recv_cdp_until(eval_id, timeout=3)
                time.sleep(4)

                scroll_id = send_cdp("Runtime.evaluate", {
                    "expression": "window.scrollTo(0, 420); document.body.scrollHeight;"
                })
                recv_cdp_until(scroll_id, timeout=3)
                time.sleep(1)

                shot_id = send_cdp("Page.captureScreenshot", {"format": "png"})
                resp = recv_cdp_until(shot_id, timeout=10)
                if resp and "result" in resp and "data" in resp["result"]:
                    img_data = base64.b64decode(resp["result"]["data"])
                    with open(out_path, "wb") as f:
                        f.write(img_data)
                else:
                    LOG.warning("No se recibió captura CDP para %s", url)

                try:
                    sock.close()
                except Exception:
                    pass

            except Exception as e:
                LOG.warning("Error en captura CDP: %s", e)
            finally:
                try:
                    proc.terminate()
                    proc.wait(timeout=3)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass

        for idx, item in enumerate(jira_worklogs, 1):
            key = item.get("key", "")
            worklog_id = item.get("worklog_id", "")
            if worklog_id:
                url = f"{domain}/browse/{key}?page=com.atlassian.jira.plugin.system.issuetabpanels%3Aworklog-tabpanel&focusedWorklogId={worklog_id}#worklog-{worklog_id}"
            else:
                url = f"{domain}/browse/{key}?page=com.atlassian.jira.plugin.system.issuetabpanels%3Aworklog-tabpanel"

            out_img = os.path.join(temp_dir, f"capture_{idx:03d}_{key}.png")
            capture_jira_tab(url, out_img)

            if os.path.exists(out_img) and os.path.getsize(out_img) > 1000:
                im = Image.open(out_img).convert("RGB")
                captured_images.append(im)

        if not captured_images:
            LOG.error("No se pudieron capturar las pantallas de Jira.")
            return

        if os.path.exists(save_path):
            try:
                os.remove(save_path)
            except Exception as rem_err:
                LOG.warning("No se pudo eliminar archivo previo %s: %s", save_path, rem_err)

        first_img = captured_images[0]
        other_imgs = captured_images[1:] if len(captured_images) > 1 else []
        first_img.save(
            save_path,
            "PDF",
            resolution=100.0,
            save_all=True,
            append_images=other_imgs
        )
        LOG.info("PDF con capturas generado/sobreescrito exitosamente: %s (%s páginas)", save_path, len(captured_images))

        pdf_uri = f"file://{os.path.abspath(save_path)}"
        try:
            subprocess.Popen(["google-chrome-stable", pdf_uri], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            webbrowser.open(pdf_uri)

    except Exception:
        LOG.exception("Error en servicio de PDF background")
    finally:
        try:
            shutil.rmtree(temp_dir, ignore_errors=True)
        except Exception:
            pass


class RegistroDiarioLucidApp(tk.Tk):
    """
    Aplicación con paleta y disposición Lucid / Motif / X11 Clásico.
    Colores: Gris Lucid (#c8c8c8 / #d4d0c8), relieve 3D bevels (raised/sunken), tipografía limpia.
    """
    def __init__(self, config):
        super().__init__()
        self.config_data = config
        self.state = load_state()
        self.selected_day = date.today().isoformat()
        self.issues = []
        self.jira_worklogs_cache = {}
        self.search_filter = ""
        self.selected_project = "Todos los proyectos"
        self.selected_parent = "Todos los parents"
        self.selected_story_key = None
        self.active_selection_type = "task"  # 'task' or 'story'
        self.is_loading = False

        self.title("Horas · Registro diario [Lucid Edition]")
        self.geometry("1400x840")
        self.minsize(1000, 650)

        self.LUCID_BG = "#c8c8c8"
        self.LUCID_PANEL_BG = "#bfbfbf"
        self.LUCID_DARK_BEVEL = "#7e7e7e"
        self.LUCID_LIGHT_BEVEL = "#ffffff"
        self.LUCID_ENTRY_BG = "#ffffff"
        self.LUCID_FG = "#000000"
        self.LUCID_HEADER_BG = "#3b5998"
        self.LUCID_HEADER_FG = "#ffffff"
        self.LUCID_ACTIVE_BG = "#316ac5"
        self.LUCID_ACTIVE_FG = "#ffffff"

        self.configure(bg=self.LUCID_BG)
        self.setup_styles()
        self.build_ui()
        self.refresh_all_async()

    def setup_styles(self):
        self.style = ttk.Style(self)
        self.style.theme_use("classic")

        FONT_MAIN = ("Helvetica", 10)
        FONT_BOLD = ("Helvetica", 10, "bold")
        FONT_TITLE = ("Helvetica", 12, "bold")

        self.style.configure(".", background=self.LUCID_BG, foreground=self.LUCID_FG, font=FONT_MAIN)
        self.style.configure("Lucid.TFrame", background=self.LUCID_BG)
        self.style.configure("LucidBevel.TFrame", background=self.LUCID_BG, relief="raised", borderwidth=2)
        self.style.configure("LucidSunken.TFrame", background=self.LUCID_BG, relief="sunken", borderwidth=2)

        self.style.configure("LucidHeader.TLabel", font=FONT_TITLE, foreground="#000080", background=self.LUCID_BG)
        self.style.configure("LucidStatus.TLabel", font=FONT_BOLD, background=self.LUCID_BG)
        self.style.configure("LucidBigTotal.TLabel", font=("Helvetica", 20, "bold"), foreground="#000080", background=self.LUCID_BG)
        self.style.configure("LucidMuted.TLabel", font=FONT_MAIN, foreground="#444444", background=self.LUCID_BG)

        self.style.configure(
            "Treeview",
            background="#ffffff",
            foreground="#000000",
            fieldbackground="#ffffff",
            rowheight=24,
            font=FONT_MAIN,
            borderwidth=2,
            relief="sunken"
        )
        self.style.configure(
            "Treeview.Heading",
            background="#d4d0c8",
            foreground="#000000",
            font=FONT_BOLD,
            borderwidth=2,
            relief="raised"
        )
        self.style.map("Treeview", background=[("selected", self.LUCID_ACTIVE_BG)], foreground=[("selected", self.LUCID_ACTIVE_FG)])
        self.style.map("Treeview.Heading", background=[("active", "#e0e0e0")])

        self.style.configure("Lucid.TButton", font=FONT_BOLD, background="#d4d0c8", foreground="#000000", borderwidth=2, relief="raised", padding=4)
        self.style.map("Lucid.TButton",
                       relief=[("pressed", "sunken"), ("!pressed", "raised")],
                       background=[("pressed", "#b0b0b0"), ("active", "#e0e0e0")])

        self.style.configure("LucidPrimary.TButton", font=FONT_BOLD, background="#316ac5", foreground="#ffffff", borderwidth=2, relief="raised", padding=5)
        self.style.map("LucidPrimary.TButton",
                       relief=[("pressed", "sunken"), ("!pressed", "raised")],
                       background=[("pressed", "#1e4887"), ("active", "#407ee0")])

    def create_lucid_button(self, parent, text, command, primary=False, **kwargs):
        """Crea botón Tkinter nativo con bordes Motif/Lucid clásicos y relieve real."""
        bg = "#316ac5" if primary else "#d4d0c8"
        fg = "#ffffff" if primary else "#000000"
        active_bg = "#1e4887" if primary else "#e0e0e0"
        active_fg = "#ffffff" if primary else "#000000"
        btn = tk.Button(
            parent,
            text=text,
            command=command,
            bg=bg,
            fg=fg,
            activebackground=active_bg,
            activeforeground=active_fg,
            relief=tk.RAISED,
            bd=2,
            font=("Helvetica", 9, "bold" if primary else "normal"),
            padx=8,
            pady=4,
            highlightthickness=1,
            highlightbackground="#808080",
            **kwargs
        )
        return btn

    def build_ui(self):
        menubar_frame = tk.Frame(self, bg=self.LUCID_BG, bd=2, relief=tk.RAISED)
        menubar_frame.pack(fill=tk.X, padx=4, pady=4)

        title_box = tk.Frame(menubar_frame, bg=self.LUCID_BG)
        title_box.pack(side=tk.LEFT, padx=8, pady=4)

        self.lbl_day_title = tk.Label(title_box, text=f"Horas · {self.selected_day}", font=("Helvetica", 12, "bold"), bg=self.LUCID_BG, fg="#000066")
        self.lbl_day_title.pack(side=tk.LEFT)

        self.lbl_loading = tk.Label(title_box, text="", fg="#990000", bg=self.LUCID_BG, font=("Helvetica", 9, "italic"))
        self.lbl_loading.pack(side=tk.LEFT, padx=16)

        nav_box = tk.Frame(menubar_frame, bg=self.LUCID_BG)
        nav_box.pack(side=tk.RIGHT, padx=8, pady=4)

        self.create_lucid_button(nav_box, "« Día anterior", self.go_prev_day).pack(side=tk.LEFT, padx=2)
        self.create_lucid_button(nav_box, "Hoy", self.go_today).pack(side=tk.LEFT, padx=2)
        self.btn_next = self.create_lucid_button(nav_box, "Día siguiente »", self.go_next_day)
        self.btn_next.pack(side=tk.LEFT, padx=2)
        self.create_lucid_button(nav_box, "🔄 Sincronizar Jira", self.refresh_all_async).pack(side=tk.LEFT, padx=6)

        main_container = tk.Frame(self, bg=self.LUCID_BG, bd=2, relief=tk.SUNKEN)
        main_container.pack(fill=tk.BOTH, expand=True, padx=6, pady=2)

        main_pane = ttk.PanedWindow(main_container, orient=tk.HORIZONTAL)
        main_pane.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)

        self.left_frame = tk.Frame(main_pane, bg="#d8d8d8", bd=2, relief=tk.GROOVE, padx=12, pady=10, width=380)
        main_pane.add(self.left_frame, weight=0)

        right_frame = tk.Frame(main_pane, bg=self.LUCID_BG, padx=8, pady=4)
        main_pane.add(right_frame, weight=1)

        self.build_right_panel(right_frame)
        self.build_left_panel()

        bottom_bar = tk.Frame(self, bg=self.LUCID_BG, bd=2, relief=tk.RAISED, padx=6, pady=4)
        bottom_bar.pack(fill=tk.X, padx=4, pady=4)

        self.create_lucid_button(bottom_bar, "📋 Ver Detalle Día (Imprimir PDF / Abrir)", self.show_day_detail).pack(side=tk.LEFT, padx=4)
        self.create_lucid_button(bottom_bar, "✕ Salir", self.destroy).pack(side=tk.RIGHT, padx=4)

    def build_left_panel(self):
        for widget in self.left_frame.winfo_children():
            widget.destroy()

        totals_box = tk.LabelFrame(self.left_frame, text=" [ Resumen de Jornada ] ", bg="#d8d8d8", fg="#000040", font=("Helvetica", 9, "bold"), bd=2, relief=tk.GROOVE, padx=8, pady=6)
        totals_box.pack(fill=tk.X, pady=(0, 10))

        self.lbl_total_hours = tk.Label(totals_box, text="0 h", font=("Helvetica", 20, "bold"), fg="#000080", bg="#d8d8d8")
        self.lbl_total_hours.pack(anchor="w")

        self.lbl_sub_hours = tk.Label(totals_box, text="Jira: 0 h · Preparadas: 0 h", font=("Helvetica", 9), fg="#333333", bg="#d8d8d8")
        self.lbl_sub_hours.pack(anchor="w", pady=(2, 4))

        self.lbl_status = tk.Label(totals_box, text="Faltan 8 h", font=("Helvetica", 10, "bold"), fg="#a00000", bg="#d8d8d8")
        self.lbl_status.pack(anchor="w", pady=(2, 4))

        is_today = (self.selected_day == date.today().isoformat())
        curr_state = day_state(self.state, self.selected_day)

        if is_today:
            is_story_mode = (self.active_selection_type == "story")
            selected_item = self.get_selected_issue()
            item_summary = f"{selected_item['key']} ({selected_item.get('type')})" if selected_item else "Ninguno"

            if is_story_mode:
                form_box = tk.LabelFrame(self.left_frame, text=" [ Registro en Historia de Usuario ] ", bg="#d8d8d8", fg="#000040", font=("Helvetica", 9, "bold"), bd=2, relief=tk.GROOVE, padx=8, pady=8)
                form_box.pack(fill=tk.BOTH, expand=True)

                lbl_info = tk.Label(
                    form_box,
                    text="Al registrar en una Historia se creará automáticamente la Tarea en Jira vinculada.",
                    font=("Helvetica", 8),
                    fg="#444444",
                    bg="#d8d8d8",
                    wraplength=320,
                    justify=tk.LEFT
                )
                lbl_info.pack(anchor="w", pady=(0, 8))

                lbl_sel = tk.Label(form_box, text=f"Historia: {item_summary}", font=("Helvetica", 9, "bold"), fg="#003399", bg="#d8d8d8", wraplength=320, justify=tk.LEFT)
                lbl_sel.pack(anchor="w", pady=(0, 8))

                row_time = tk.Frame(form_box, bg="#d8d8d8")
                row_time.pack(fill=tk.X, pady=4)

                tk.Label(row_time, text="Tiempo:", bg="#d8d8d8", font=("Helvetica", 9, "bold")).pack(side=tk.LEFT)
                self.combo_qty = ttk.Combobox(row_time, values=[0.5, 1, 1.5, 2, 2.5, 3, 4, 8], width=5, state="readonly")
                self.combo_qty.set(float(curr_state.get("selected", 1)))
                self.combo_qty.pack(side=tk.LEFT, padx=6)

                self.combo_unit = ttk.Combobox(row_time, values=["Horas"], width=7, state="readonly")
                self.combo_unit.set("Horas")
                self.combo_unit.pack(side=tk.LEFT, padx=4)

                tk.Label(form_box, text="Ceremonia / Actividad:", bg="#d8d8d8", font=("Helvetica", 9, "bold")).pack(anchor="w", pady=(8, 2))
                self.combo_act = ttk.Combobox(
                    form_box,
                    values=["Refinamiento", "Planning", "Retrospectiva", "Adicional"],
                    state="readonly"
                )
                current_act = curr_state.get("activity", "Refinamiento")
                if current_act not in ["Refinamiento", "Planning", "Retrospectiva", "Adicional"]:
                    current_act = "Refinamiento"
                self.combo_act.set(current_act)
                self.combo_act.pack(fill=tk.X, pady=(0, 8))

                tk.Label(form_box, text="Detalle de la tarea a crear:", bg="#d8d8d8", font=("Helvetica", 9, "bold")).pack(anchor="w", pady=(4, 2))
                self.entry_detail = tk.Entry(form_box, bg="#ffffff", fg="#000000", bd=2, relief=tk.SUNKEN)
                self.entry_detail.pack(fill=tk.X, pady=(0, 14))

                self.create_lucid_button(form_box, "🚀 Crear tarea y registrar en Jira", self.register_direct_jira, primary=True).pack(fill=tk.X, pady=4)
                self.create_lucid_button(form_box, "⚡ Preparar registro local", self.insert_local_work).pack(fill=tk.X, pady=4)

            else:
                form_box = tk.LabelFrame(self.left_frame, text=" [ Registro en Tarea ] ", bg="#d8d8d8", fg="#000040", font=("Helvetica", 9, "bold"), bd=2, relief=tk.GROOVE, padx=8, pady=8)
                form_box.pack(fill=tk.BOTH, expand=True)

                lbl_sel = tk.Label(form_box, text=f"Tarea: {item_summary}", font=("Helvetica", 9, "bold"), fg="#003399", bg="#d8d8d8", wraplength=320, justify=tk.LEFT)
                lbl_sel.pack(anchor="w", pady=(0, 10))

                row_time = tk.Frame(form_box, bg="#d8d8d8")
                row_time.pack(fill=tk.X, pady=(4, 14))

                tk.Label(row_time, text="Cantidad:", bg="#d8d8d8", font=("Helvetica", 9, "bold")).pack(side=tk.LEFT)
                self.combo_qty = ttk.Combobox(row_time, values=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10], width=5, state="readonly")
                self.combo_qty.set(int(float(curr_state.get("selected", 1))))
                self.combo_qty.pack(side=tk.LEFT, padx=6)

                tk.Label(row_time, text="Unidad:", bg="#d8d8d8", font=("Helvetica", 9, "bold")).pack(side=tk.LEFT, padx=(6, 0))
                self.combo_unit = ttk.Combobox(row_time, values=["Horas", "Minutos"], width=8, state="readonly")
                self.combo_unit.set(curr_state.get("unit", "Horas"))
                self.combo_unit.pack(side=tk.LEFT, padx=6)
                self.combo_unit.bind("<<ComboboxSelected>>", self.on_unit_change)

                self.create_lucid_button(form_box, "⚡ INSERTAR HORAS EN JIRA", self.register_direct_jira, primary=True).pack(fill=tk.X, pady=(10, 4))
                self.create_lucid_button(form_box, "💾 Guardar en lista local", self.insert_local_work).pack(fill=tk.X, pady=4)
        else:
            hist_box = tk.LabelFrame(self.left_frame, text=" [ Consulta Histórica ] ", bg="#d8d8d8", fg="#000040", font=("Helvetica", 9, "bold"), bd=2, relief=tk.GROOVE, padx=8, pady=8)
            hist_box.pack(fill=tk.BOTH, expand=True)

            tk.Label(hist_box, text=f"{format_date_es(self.selected_day)}", font=("Helvetica", 9, "bold"), bg="#d8d8d8", fg="#000066").pack(anchor="w", pady=(4, 2))
            tk.Label(hist_box, text="Visualizando registros de jornadas anteriores.", font=("Helvetica", 8), bg="#d8d8d8", fg="#555555").pack(anchor="w")

    def on_unit_change(self, event=None):
        unit = self.combo_unit.get()
        if unit == "Minutos":
            self.combo_qty["values"] = [15, 30, 45, 60, 90, 120]
            self.combo_qty.set(30)
        else:
            self.combo_qty["values"] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            self.combo_qty.set(1)

    def build_right_panel(self, parent):
        filter_box = tk.Frame(parent, bg=self.LUCID_BG, bd=2, relief=tk.GROOVE, padx=6, pady=4)
        filter_box.pack(fill=tk.X, pady=(0, 4))

        self.controls_bar = tk.Frame(filter_box, bg=self.LUCID_BG)
        self.controls_bar.pack(fill=tk.X)

        tk.Label(self.controls_bar, text="📁 Proyecto:", font=("Helvetica", 9, "bold"), bg=self.LUCID_BG).pack(side=tk.LEFT, padx=(0, 4))
        self.combo_project = ttk.Combobox(self.controls_bar, values=["Todos los proyectos"], width=20, state="readonly")
        self.combo_project.set("Todos los proyectos")
        self.combo_project.pack(side=tk.LEFT, padx=(0, 10))
        self.combo_project.bind("<<ComboboxSelected>>", self.on_project_change)

        tk.Label(self.controls_bar, text="📑 Parent:", font=("Helvetica", 9, "bold"), bg=self.LUCID_BG).pack(side=tk.LEFT, padx=(0, 4))
        self.combo_parent = ttk.Combobox(self.controls_bar, values=["Todos los parents"], width=28, state="readonly")
        self.combo_parent.set("Todos los parents")
        self.combo_parent.pack(side=tk.LEFT, padx=(0, 10))
        self.combo_parent.bind("<<ComboboxSelected>>", self.on_parent_change)

        self.entry_search = tk.Entry(self.controls_bar, width=16, bg="#ffffff", fg="#000000", bd=2, relief=tk.SUNKEN)
        self.entry_search.pack(side=tk.RIGHT)
        self.entry_search.bind("<KeyRelease>", self.on_search)

        tk.Label(self.controls_bar, text="🔍 Buscar:", font=("Helvetica", 9, "bold"), bg=self.LUCID_BG).pack(side=tk.RIGHT, padx=(0, 4))

        # SECCIÓN SUPERIOR: TAREAS
        self.upper_frame = tk.Frame(parent, bg=self.LUCID_BG)
        self.upper_frame.pack(fill=tk.BOTH, expand=True, pady=(2, 4))

        upper_header_box = tk.Frame(self.upper_frame, bg=self.LUCID_BG)
        upper_header_box.pack(fill=tk.X, pady=(0, 2))

        self.lbl_tasks_header = tk.Label(upper_header_box, text="⚡ Tareas asignadas", font=("Helvetica", 10, "bold"), bg=self.LUCID_BG, fg="#000066")
        self.lbl_tasks_header.pack(side=tk.LEFT)

        self.btn_clear_story = self.create_lucid_button(upper_header_box, "Ver todas las tareas", self.clear_story_selection)
        self.btn_clear_story.pack(side=tk.RIGHT)

        tree_tasks_box = tk.Frame(self.upper_frame, bg=self.LUCID_BG, bd=2, relief=tk.SUNKEN)
        tree_tasks_box.pack(fill=tk.BOTH, expand=True)

        self.tree_tasks = ttk.Treeview(tree_tasks_box, style="Treeview", selectmode="browse", show="headings")
        v_scroll_tasks = tk.Scrollbar(tree_tasks_box, orient=tk.VERTICAL, command=self.tree_tasks.yview)
        self.tree_tasks.configure(yscrollcommand=v_scroll_tasks.set)

        self.tree_tasks.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll_tasks.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree_tasks.bind("<<TreeviewSelect>>", self.on_task_select)
        self.tree_tasks.bind("<Double-1>", self.on_task_double_click)

        # SECCIÓN INFERIOR: HISTORIAS DE USUARIO
        self.lower_frame = tk.Frame(parent, bg=self.LUCID_BG)
        self.lower_frame.pack(fill=tk.BOTH, expand=True, pady=(4, 0))

        lower_header_box = tk.Frame(self.lower_frame, bg=self.LUCID_BG)
        lower_header_box.pack(fill=tk.X, pady=(0, 2))

        self.lbl_stories_header = tk.Label(lower_header_box, text="📖 Historias de Usuario (Selecciona para ver sus tareas vinculadas o crear tareas)", font=("Helvetica", 10, "bold"), bg=self.LUCID_BG, fg="#000066")
        self.lbl_stories_header.pack(side=tk.LEFT)

        tree_stories_box = tk.Frame(self.lower_frame, bg=self.LUCID_BG, bd=2, relief=tk.SUNKEN)
        tree_stories_box.pack(fill=tk.BOTH, expand=True)

        self.tree_stories = ttk.Treeview(tree_stories_box, style="Treeview", selectmode="browse", show="headings")
        v_scroll_stories = tk.Scrollbar(tree_stories_box, orient=tk.VERTICAL, command=self.tree_stories.yview)
        self.tree_stories.configure(yscrollcommand=v_scroll_stories.set)

        self.tree_stories.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll_stories.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree_stories.bind("<<TreeviewSelect>>", self.on_story_select)
        self.tree_stories.bind("<Double-1>", self.on_story_double_click)

    def on_task_select(self, event=None):
        if self.tree_tasks.selection():
            self.active_selection_type = "task"
            self.build_left_panel()

    def on_story_select(self, event=None):
        sel = self.tree_stories.selection()
        if sel:
            vals = self.tree_stories.item(sel[0], "values")
            if vals:
                self.selected_story_key = vals[0]
                self.active_selection_type = "story"
                self.build_left_panel()
                self.render_tasks_table()

    def clear_story_selection(self):
        self.selected_story_key = None
        self.tree_stories.selection_remove(self.tree_stories.selection())
        self.active_selection_type = "task"
        self.build_left_panel()
        self.render_tasks_table()

    def update_project_dropdown(self):
        projects_ordered = []
        for it in self.issues:
            p = it.get("project")
            if p and p != "-" and p not in projects_ordered:
                projects_ordered.append(p)

        options = ["Todos los proyectos"] + projects_ordered
        self.combo_project["values"] = options

        if projects_ordered and (self.selected_project == "Todos los proyectos" or self.selected_project not in options):
            self.selected_project = projects_ordered[0]

        self.combo_project.set(self.selected_project)
        self.update_parent_dropdown()

    def update_parent_dropdown(self):
        parents_ordered = []
        for it in self.issues:
            if self.selected_project != "Todos los proyectos" and it.get("project") != self.selected_project:
                continue
            parent_name = it.get("parent")
            if parent_name and parent_name != "-" and parent_name not in parents_ordered:
                parents_ordered.append(parent_name)

        options = ["Todos los parents"] + parents_ordered
        self.combo_parent["values"] = options

        if parents_ordered and (self.selected_parent == "Todos los parents" or self.selected_parent not in options):
            self.selected_parent = parents_ordered[0]
        elif not parents_ordered:
            self.selected_parent = "Todos los parents"

        self.combo_parent.set(self.selected_parent)

    def on_project_change(self, event=None):
        self.selected_project = self.combo_project.get()
        self.selected_parent = "Todos los parents"
        self.selected_story_key = None
        self.update_parent_dropdown()
        self.render_table()

    def on_parent_change(self, event=None):
        self.selected_parent = self.combo_parent.get()
        self.selected_story_key = None
        self.render_table()

    def update_totals_ui(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        jira_total = sum(float(item.get("hours", 0)) for item in jira_worklogs)
        local_total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total = jira_total + local_total
        min_hours = 6.5
        max_hours = 10.5

        self.lbl_day_title.config(text=f"Horas · {format_date_es(self.selected_day)}")
        self.lbl_total_hours.config(text=format_hours(total))
        self.lbl_sub_hours.config(text=f"Jira: {format_hours(jira_total)}  ·  Preparadas: {format_hours(local_total)}")

        if total < min_hours:
            diff_min = min_hours - total
            self.lbl_status.config(text=f"Faltan mínimo {format_hours(diff_min)}", fg="#b30000")
        elif total <= max_hours:
            self.lbl_status.config(text="✓ Jornada completa", fg="#006600")
        else:
            diff_over = total - max_hours
            self.lbl_status.config(text=f"⚠ Se sobrepasó por {format_hours(diff_over)}", fg="#b30000")

        is_today = (self.selected_day == date.today().isoformat())
        self.btn_next.config(state=tk.DISABLED if is_today else tk.NORMAL)

    def render_table(self):
        is_today = (self.selected_day == date.today().isoformat())
        query = self.search_filter.lower().strip()

        if is_today:
            self.controls_bar.pack(fill=tk.X)
            self.btn_clear_story.pack(side=tk.RIGHT)
            self.lower_frame.pack(fill=tk.BOTH, expand=True)
            self.render_tasks_table()
            self.render_stories_table()
        else:
            self.controls_bar.pack_forget()
            self.btn_clear_story.pack_forget()
            self.lower_frame.pack_forget()
            self.tree_tasks.delete(*self.tree_tasks.get_children())
            curr_state = day_state(self.state, self.selected_day)
            jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
            historical = [*jira_worklogs, *curr_state.get("worklogs", [])]

            self.lbl_tasks_header.config(text=f"Trabajo realizado ({len(historical)} registros del {format_date_es(self.selected_day)})")
            self.tree_tasks["columns"] = ("key", "story", "summary", "hours")

            headers = [
                ("key", "Clave", 120),
                ("story", "Historia / Parent Asociada", 360),
                ("summary", "Tarea", 580),
                ("hours", "Horas", 100),
            ]
            for col_id, col_text, col_width in headers:
                self.tree_tasks.heading(col_id, text=col_text)
                self.tree_tasks.column(col_id, width=col_width, minwidth=60)

            for item in historical:
                text_to_search = f"{item.get('key', '')} {item.get('story', '')} {item.get('summary', '')}".lower()
                if query and query not in text_to_search:
                    continue
                self.tree_tasks.insert("", tk.END, values=(
                    item.get("key", "—"),
                    item.get("story", "—"),
                    item.get("summary", ""),
                    format_hours(item.get("hours", 0))
                ))

    def render_tasks_table(self):
        self.tree_tasks.delete(*self.tree_tasks.get_children())
        query = self.search_filter.lower().strip()

        tasks_list = [it for it in self.issues if it.get("type") not in ("Historia de usuario", "Story", "Historia")]
        selected_story = next((it for it in self.issues if it["key"] == self.selected_story_key), None) if self.selected_story_key else None
        story_linked_task_keys = set(selected_story.get("linked_tasks", [])) if selected_story else set()

        filtered_tasks = []
        for task in tasks_list:
            if self.selected_project != "Todos los proyectos" and task.get("project") != self.selected_project:
                continue
            if self.selected_parent != "Todos los parents" and task.get("parent") != self.selected_parent:
                continue

            if self.selected_story_key:
                is_linked = (self.selected_story_key in task.get("linked_stories", [])) or (task["key"] in story_linked_task_keys)
                if not is_linked:
                    continue

            text_to_search = f"{task['key']} {task['project']} {task['parent']} {task['summary']} {task['status']}".lower()
            if query and query not in text_to_search:
                continue
            filtered_tasks.append(task)

        if self.selected_story_key:
            self.lbl_tasks_header.config(text=f"⚡ Tareas asociadas a {self.selected_story_key} ({len(filtered_tasks)} encontradas)")
        else:
            self.lbl_tasks_header.config(text=f"⚡ Todas mis tareas asignadas ({len(filtered_tasks)} disponibles)")

        self.tree_tasks["columns"] = ("key", "summary", "status", "hours")
        headers = [
            ("key", "Clave", 120),
            ("summary", "Tarea", 760),
            ("status", "Estado", 140),
            ("hours", "Horas Jira", 100),
        ]
        for col_id, col_text, col_width in headers:
            self.tree_tasks.heading(col_id, text=col_text)
            self.tree_tasks.column(col_id, width=col_width, minwidth=60)

        for task in filtered_tasks:
            self.tree_tasks.insert("", tk.END, values=(
                task["key"],
                task["summary"],
                task["status"],
                task["hours"]
            ))

    def render_stories_table(self):
        self.tree_stories.delete(*self.tree_stories.get_children())
        query = self.search_filter.lower().strip()

        stories_list = [it for it in self.issues if it.get("type") in ("Historia de usuario", "Story", "Historia")]

        filtered_stories = []
        for story in stories_list:
            if self.selected_project != "Todos los proyectos" and story.get("project") != self.selected_project:
                continue
            if self.selected_parent != "Todos los parents" and story.get("parent") != self.selected_parent:
                continue
            text_to_search = f"{story['key']} {story['project']} {story['parent']} {story['summary']} {story['status']}".lower()
            if query and query not in text_to_search:
                continue
            filtered_stories.append(story)

        self.lbl_stories_header.config(text=f"📖 Historias de Usuario ({len(filtered_stories)} disponibles)")
        self.tree_stories["columns"] = ("key", "summary", "status", "hours")
        headers = [
            ("key", "Clave", 120),
            ("summary", "Historia", 760),
            ("status", "Estado", 140),
            ("hours", "Horas Jira", 100),
        ]
        for col_id, col_text, col_width in headers:
            self.tree_stories.heading(col_id, text=col_text)
            self.tree_stories.column(col_id, width=col_width, minwidth=60)

        for story in filtered_stories:
            item_id = self.tree_stories.insert("", tk.END, values=(
                story["key"],
                story["summary"],
                story["status"],
                story["hours"]
            ))
            if self.selected_story_key and story["key"] == self.selected_story_key:
                self.tree_stories.selection_set(item_id)

    def on_search(self, event=None):
        self.search_filter = self.entry_search.get()
        self.render_table()

    def get_selected_issue(self):
        if self.active_selection_type == "story":
            sel = self.tree_stories.selection()
            if sel:
                vals = self.tree_stories.item(sel[0], "values")
                if vals:
                    return next((it for it in self.issues if it["key"] == vals[0]), None)
        else:
            sel = self.tree_tasks.selection()
            if sel:
                vals = self.tree_tasks.item(sel[0], "values")
                if vals:
                    return next((it for it in self.issues if it["key"] == vals[0]), None)
        return None

    def on_task_double_click(self, event=None):
        if self.selected_day == date.today().isoformat():
            self.active_selection_type = "task"
            self.insert_local_work()

    def on_story_double_click(self, event=None):
        if self.selected_day == date.today().isoformat():
            self.active_selection_type = "story"
            self.build_left_panel()

    def insert_local_work(self):
        issue = self.get_selected_issue()
        if not issue:
            messagebox.showwarning("Selecciona una tarea o historia", "Selecciona una tarea o historia de la lista antes de insertar.")
            return

        unit = self.combo_unit.get() if hasattr(self, 'combo_unit') else "Horas"
        try:
            amount = float(self.combo_qty.get())
        except (ValueError, TypeError, AttributeError):
            amount = 1.0

        hours = amount / 60.0 if unit == "Minutos" else amount
        curr_state = day_state(self.state, self.selected_day)
        curr_state["selected"] = amount
        curr_state["unit"] = unit

        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total += sum(float(item.get("hours", 0)) for item in jira_worklogs)

        if total + hours > 10.5:
            messagebox.showwarning("Máximo diario", "El registro superaría el máximo diario de 10 h 30 min.")
            return

        is_story = (self.active_selection_type == 'story')
        activity = self.combo_act.get() if (is_story and hasattr(self, 'combo_act')) else "Trabajo en tarea"
        detail = self.entry_detail.get().strip() if (is_story and hasattr(self, 'entry_detail')) else ""
        final_activity = detail if activity == "Adicional" and detail else activity

        curr_state["worklogs"].append({
            "key": issue["key"],
            "summary": f"{activity}: {detail}" if (is_story and detail) else issue["summary"],
            "hours": hours,
            "activity": final_activity,
            "created": datetime.now().isoformat(timespec="seconds"),
        })
        save_state(self.state)
        LOG.info("Registro local preparado: %s %s %.2f h", self.selected_day, issue["key"], hours)

        self.update_totals_ui()
        if is_story and hasattr(self, 'entry_detail'):
            self.entry_detail.delete(0, tk.END)
        messagebox.showinfo("Registro preparado", f"Se añadieron {format_hours(hours)} a {issue['key']} en la lista preparada.")

    def register_direct_jira(self):
        issue = self.get_selected_issue()
        if not issue:
            messagebox.showwarning("Selecciona un elemento", "Selecciona una tarea o historia de la lista antes de registrar.")
            return

        unit = self.combo_unit.get() if hasattr(self, 'combo_unit') else "Horas"
        try:
            amount = float(self.combo_qty.get())
        except (ValueError, TypeError, AttributeError):
            amount = 1.0

        hours = amount / 60.0 if unit == "Minutos" else amount
        is_story = (issue.get("type") in ("Historia de usuario", "Story", "Historia"))
        activity = self.combo_act.get() if (is_story and hasattr(self, 'combo_act')) else "Trabajo en tarea"
        detail = self.entry_detail.get().strip() if (is_story and hasattr(self, 'entry_detail')) else ""
        if not detail:
            detail = activity if is_story else issue["summary"]

        if is_story:
            prompt_text = (
                f"Estás en una HISTORIA DE USUARIO.\n\n"
                f"Se creará una nueva TAREA en Jira:\n"
                f"• Resumen: '{activity}: {detail}'\n"
                f"• Vinculada a Historia: {issue['key']} - {issue['summary']}\n"
                f"• Tiempo a registrar: {format_hours(hours)}\n\n"
                f"¿Deseas crear la tarea y registrar las horas?"
            )
        else:
            prompt_text = (
                f"¿Deseas registrar en Jira?\n\n"
                f"Tarea: {issue['key']}\n"
                f"Tiempo: {format_hours(hours)}\n"
                f"Descripción: {issue['summary']}"
            )

        confirm = messagebox.askyesno("Confirmar registro en Jira", prompt_text)
        if not confirm:
            return

        self.set_loading(True, "Creando tarea y registrando en Jira…" if is_story else "Registrando en Jira…")

        def task():
            try:
                target_key = issue["key"]
                if is_story:
                    new_task_key, _ = create_task_for_story(self.config_data, issue, activity, detail)
                    target_key = new_task_key
                    LOG.info("Tarea creada en Jira para la historia %s: %s", issue["key"], new_task_key)

                url = register_in_jira(self.config_data, target_key, hours, activity, detail)
                self.jira_worklogs_cache.pop(self.selected_day, None)

                new_issues = get_issues(self.config_data)
                new_logs = get_jira_worklogs(self.config_data, self.selected_day)
                self.issues = new_issues
                self.jira_worklogs_cache[self.selected_day] = new_logs

                def on_success():
                    self.set_loading(False)
                    self.update_project_dropdown()
                    self.update_totals_ui()
                    self.render_table()
                    msg = f"¡Tarea {target_key} creada y {format_hours(hours)} registradas en Jira!\n\n¿Deseas abrirla en el navegador?" if is_story else f"¡{format_hours(hours)} registradas en {target_key}!\n\n¿Deseas abrirla en el navegador?"
                    if messagebox.askyesno("Registro exitoso", msg):
                        webbrowser.open(url)

                self.after(0, on_success)
            except Exception as err:
                def on_fail():
                    self.set_loading(False)
                    LOG.exception("Error al registrar en Jira")
                    messagebox.showerror("Error al registrar en Jira", str(err))

                self.after(0, on_fail)

        threading.Thread(target=task, daemon=True).start()

    def go_prev_day(self):
        d = datetime.strptime(self.selected_day, "%Y-%m-%d").date() - timedelta(days=1)
        self.selected_day = d.isoformat()
        self.on_day_changed()

    def go_today(self):
        self.selected_day = date.today().isoformat()
        self.on_day_changed()

    def go_next_day(self):
        d = datetime.strptime(self.selected_day, "%Y-%m-%d").date() + timedelta(days=1)
        self.selected_day = min(d.isoformat(), date.today().isoformat())
        self.on_day_changed()

    def on_day_changed(self):
        LOG.info("Cambio de fecha: %s", self.selected_day)
        self.build_left_panel()
        self.update_totals_ui()
        self.render_table()

        if self.selected_day not in self.jira_worklogs_cache:
            self.fetch_day_worklogs_async(self.selected_day)

    def set_loading(self, loading, text=""):
        self.is_loading = loading
        self.lbl_loading.config(text=text if loading else "")
        self.update_idletasks()

    def fetch_day_worklogs_async(self, target_day):
        self.set_loading(True, f"Cargando registros del {target_day}…")

        def task():
            try:
                logs = get_jira_worklogs(self.config_data, target_day)
                self.jira_worklogs_cache[target_day] = logs

                def update():
                    if self.selected_day == target_day:
                        self.set_loading(False)
                        self.update_totals_ui()
                        self.render_table()

                self.after(0, update)
            except Exception as e:
                def on_error():
                    self.set_loading(False)
                    LOG.warning("Error cargando worklogs para %s: %s", target_day, e)

                self.after(0, on_error)

        threading.Thread(target=task, daemon=True).start()

    def refresh_all_async(self):
        self.set_loading(True, "Sincronizando con Jira…")

        def task():
            try:
                issues = get_issues(self.config_data)
                logs = get_jira_worklogs(self.config_data, self.selected_day)
                self.issues = issues
                self.jira_worklogs_cache[self.selected_day] = logs

                def update_ui():
                    self.set_loading(False)
                    self.update_project_dropdown()
                    self.update_totals_ui()
                    self.render_table()

                self.after(0, update_ui)
            except Exception as e:
                err_msg = str(e)
                def on_error():
                    self.set_loading(False)
                    LOG.exception("Error al actualizar Jira")
                    messagebox.showerror("Error de conexión Jira", err_msg)

                self.after(0, on_error)

        threading.Thread(target=task, daemon=True).start()

    def show_day_detail(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        all_rows = [*jira_worklogs, *curr_state.get("worklogs", [])]

        win = tk.Toplevel(self)
        win.title(f"Detalle · {format_date_es(self.selected_day)} [Lucid]")
        win.geometry("1100x520")
        win.configure(bg=self.LUCID_BG)

        header_frame = tk.Frame(win, bg=self.LUCID_BG, bd=2, relief=tk.RAISED, padx=8, pady=6)
        header_frame.pack(fill=tk.X, padx=4, pady=4)

        tk.Label(header_frame, text=f"Registros del {format_date_es(self.selected_day)}", font=("Helvetica", 11, "bold"), bg=self.LUCID_BG, fg="#000066").pack(anchor="w")

        tree_frame = tk.Frame(win, bg=self.LUCID_BG, bd=2, relief=tk.SUNKEN)
        tree_frame.pack(fill=tk.BOTH, expand=True, padx=6, pady=4)

        tree = ttk.Treeview(tree_frame, columns=("key", "story", "summary", "hours"), show="headings", style="Treeview")
        v_scroll = tk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=tree.yview)
        tree.configure(yscrollcommand=v_scroll.set)

        tree.heading("key", text="Clave")
        tree.heading("story", text="Historia / Parent Asociada")
        tree.heading("summary", text="Tarea")
        tree.heading("hours", text="Horas")

        tree.column("key", width=120, minwidth=80)
        tree.column("story", width=420, minwidth=200)
        tree.column("summary", width=500, minwidth=220)
        tree.column("hours", width=90, minwidth=60)

        for it in all_rows:
            tree.insert("", tk.END, values=(
                it.get("key", "—"),
                it.get("story", "—"),
                it.get("summary", ""),
                format_hours(it.get("hours", 0))
            ))

        tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        def open_selected(event=None):
            selection = tree.selection()
            if not selection:
                return
            vals = tree.item(selection[0], "values")
            if vals:
                k = vals[0]
                if k and k != "—":
                    domain = self.config_data.get("JIRA_DOMAIN", "").rstrip("/")
                    webbrowser.open(f"{domain}/browse/{k}")

        tree.bind("<Double-1>", open_selected)

        btn_bar = tk.Frame(win, bg=self.LUCID_BG, bd=2, relief=tk.RAISED, padx=8, pady=6)
        btn_bar.pack(fill=tk.X, padx=4, pady=4)

        def open_in_browser():
            selection = tree.selection()
            if not selection:
                messagebox.showwarning("Selecciona un registro", "Selecciona una fila para abrir en el navegador.")
                return
            vals = tree.item(selection[0], "values")
            if vals:
                k = vals[0]
                if k and k != "—":
                    domain = self.config_data.get("JIRA_DOMAIN", "").rstrip("/")
                    webbrowser.open(f"{domain}/browse/{k}")

        def print_pdf():
            if not all_rows:
                messagebox.showwarning("Sin registros", "No hay registros disponibles para generar el PDF.")
                return

            script_path = os.path.abspath(__file__)
            day_arg = self.selected_day
            subprocess.Popen([sys.executable, script_path, "--generate-pdf-bg", day_arg],
                             start_new_session=True,
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)

            try:
                win.destroy()
                self.destroy()
            except Exception:
                pass
            os._exit(0)

        self.create_lucid_button(btn_bar, "📄 Imprimir PDF (1 pág/reg)", print_pdf, primary=True).pack(side=tk.LEFT, padx=4)
        self.create_lucid_button(btn_bar, "Abrir seleccionado en Jira", open_in_browser).pack(side=tk.LEFT, padx=4)
        self.create_lucid_button(btn_bar, "Cerrar", win.destroy).pack(side=tk.RIGHT, padx=4)


def main():
    if "--generate-pdf-bg" in sys.argv:
        try:
            config = read_config()
            target_date = sys.argv[sys.argv.index("--generate-pdf-bg") + 1] if len(sys.argv) > sys.argv.index("--generate-pdf-bg") + 1 else date.today().isoformat()
            generate_pdf_in_background(config, target_date)
            return 0
        except Exception:
            LOG.exception("Error ejecutando generate_pdf_in_background")
            return 1

    LOG.info("Inicio de la aplicación con frontend Tkinter Lucid")
    if not os.path.exists(CONFIG):
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror("Falta configuración", f"No existe el archivo de configuración en:\n{CONFIG}")
        return 1

    try:
        config = read_config()
    except Exception as error:
        root = tk.Tk()
        root.withdraw()
        LOG.exception("Error al leer configuración")
        messagebox.showerror("Error de configuración", str(error))
        return 1

    app = RegistroDiarioLucidApp(config)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
