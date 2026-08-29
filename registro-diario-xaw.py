#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
registro-diario-xaw.py - Interfaz de registro diario con estética pura Xaw / Athena Widgets (xterm style).
Características Athena/Xaw:
- Scrollbar clásico estilo xterm (sin flechas, thumb plano con borde sólido y click interactivo tipo Athena).
- Paleta y acabados Athena clásicos: gris cemento (#c0c0c0 / #d0d0d0), bordes sólidos negros (1px/2px), sin redondeos.
- Tipografía monoespaciada tipo Courier / Fixed de terminal UNIX / X11.
- Botones planos con feedback de inversión (highlight/invertido) clásico de Xaw Command widgets.
- Conserva el 100% de la lógica de Jira, gestión de historias/tareas y generación de PDF.
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
from tkinter import messagebox
from PIL import Image

def html_escape(text):
    return html.escape(str(text or ""))

CONFIG = os.path.expanduser("~/.justificar/jira_config")
CSV = os.path.expanduser("~/.justificar/justificar.csv")
STATE_FILE = os.path.expanduser("~/.justificar/registro-diario-yad.json")
LOG_FILE = os.path.expanduser("~/.justificar/registro-diario-xaw.log")


def setup_logging():
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logger = logging.getLogger("registro-diario-xaw")
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
    jql_tasks = ('(assignee = currentUser() OR worklogAuthor = currentUser()) '
                 'AND (statusCategory != Done OR status = "En medición" OR sprint in openSprints()) '
                 'AND issuetype in (Task, Tarea, "Sub-task", Subtarea, Correctivos, "Error en producción", Incidencias) '
                 'ORDER BY updated DESC')
    
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


# ==============================================================================
# WIDGET PERSONALIZADO: XAW / XTERM SCROLLBAR
# ==============================================================================
class XawScrollbar(tk.Canvas):
    """
    Scrollbar estilo xterm / Athena (Xaw):
    - Sin flechas triangulares arriba/abajo.
    - Canal con borde sólido de 1px/2px.
    - Thumb negro/gris con borde sólido que representa la porción visible.
    - Comportamiento clásico Athena:
        * Botón 1 (Clic Izq): Bajar contenido (avanzar).
        * Botón 2 (Clic Central): Mover y arrastrar thumb directamente.
        * Botón 3 (Clic Der): Subir contenido (retroceder).
        * Rueda del ratón: Scroll arriba/abajo.
    """
    def __init__(self, parent, command=None, width=15, **kwargs):
        super().__init__(
            parent,
            width=width,
            bg="#d0d0d0",          # Trough background (Gris Athena)
            highlightthickness=1,
            highlightbackground="#000000",
            bd=0,
            **kwargs
        )
        self.command = command
        self.first = 0.0
        self.last = 1.0
        self.is_dragging = False

        self.bind("<Configure>", self._redraw)
        self.bind("<Button-1>", self._on_btn1) # Scroll down
        self.bind("<Button-2>", self._on_btn2) # Jump / start drag
        self.bind("<B2-Motion>", self._on_drag)
        self.bind("<Button-3>", self._on_btn3) # Scroll up
        self.bind("<MouseWheel>", self._on_wheel)
        self.bind("<Button-4>", lambda e: self._scroll_units(-3))
        self.bind("<Button-5>", lambda e: self._scroll_units(3))

    def set(self, first, last):
        self.first = float(first)
        self.last = float(last)
        self._redraw()

    def _redraw(self, event=None):
        self.delete("all")
        h = self.winfo_height()
        w = self.winfo_width()
        if h <= 2:
            return

        y0 = int(self.first * h)
        y1 = int(self.last * h)
        if y1 - y0 < 10:
            y1 = min(h, y0 + 10)

        # Dibujar Thumb estilo Xaw / xterm: rectángulo sólido con borde negro y stipple opcional
        self.create_rectangle(
            1, y0, w - 2, y1,
            fill="#707070",
            outline="#000000",
            width=1,
            tags="thumb"
        )
        # Línea central decorativa de agarre
        mid = (y0 + y1) // 2
        self.create_line(3, mid, w - 4, mid, fill="#000000")

    def _on_btn1(self, event):
        # Click Izq en Athena: salta hacia adelante según la posición relativa
        frac = event.y / max(1, self.winfo_height())
        if self.command:
            self.command("scroll", int(frac * 10) or 1, "pages")

    def _on_btn3(self, event):
        # Click Der en Athena: salta hacia atrás
        frac = event.y / max(1, self.winfo_height())
        if self.command:
            self.command("scroll", -(int(frac * 10) or 1), "pages")

    def _on_btn2(self, event):
        # Click Central en Athena: jump directo
        h = self.winfo_height()
        frac = event.y / max(1, h)
        if self.command:
            self.command("moveto", frac)

    def _on_drag(self, event):
        h = self.winfo_height()
        frac = max(0.0, min(1.0, event.y / max(1, h)))
        if self.command:
            self.command("moveto", frac)

    def _on_wheel(self, event):
        if event.delta:
            delta = -int(event.delta / 120)
            self._scroll_units(delta * 3)

    def _scroll_units(self, units):
        if self.command:
            self.command("scroll", units, "units")


# ==============================================================================
# APLICACIÓN PRINCIPAL ATHENA / XAW
# ==============================================================================
class RegistroDiarioXawApp(tk.Tk):
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

        self.title("Horas · Registro diario [Xaw / Athena]")
        self.geometry("1380x840")
        self.minsize(1000, 650)

        # Paleta Athena / Xaw
        self.XAW_BG = "#c0c0c0"
        self.XAW_PANEL_BG = "#c8c8c8"
        self.XAW_BLACK = "#000000"
        self.XAW_WHITE = "#ffffff"
        self.XAW_SEL_BG = "#000000"
        self.XAW_SEL_FG = "#ffffff"
        self.XAW_BORDER = "#000000"

        # Tipografías UNIX X11 fijas
        self.FONT_MAIN = ("Courier", 10)
        self.FONT_BOLD = ("Courier", 10, "bold")
        self.FONT_TITLE = ("Courier", 12, "bold")
        self.FONT_BIG = ("Courier", 18, "bold")

        self.configure(bg=self.XAW_BG)
        self.build_ui()
        self.refresh_all_async()

    def create_xaw_button(self, parent, text, command, highlight=False, width=None, **kwargs):
        """Crea botón plano clásico Athena Command Widget con borde negro e inversión al hacer clic."""
        bg = "#b8b8b8" if not highlight else "#a0a0a0"
        fg = self.XAW_BLACK
        btn = tk.Button(
            parent,
            text=text,
            command=command,
            bg=bg,
            fg=fg,
            activebackground=self.XAW_BLACK,
            activeforeground=self.XAW_WHITE,
            relief=tk.FLAT,
            bd=0,
            highlightthickness=2,
            highlightbackground=self.XAW_BLACK,
            highlightcolor=self.XAW_BLACK,
            font=self.FONT_BOLD if highlight else self.FONT_MAIN,
            padx=6,
            pady=3,
            cursor="hand2",
            **kwargs
        )
        if width:
            btn.config(width=width)
        return btn

    def build_ui(self):
        # 1. Barra superior tipo Xaw Box / MenuBar
        topbar = tk.Frame(self, bg=self.XAW_BG, bd=2, relief=tk.SOLID, padx=6, pady=4)
        topbar.pack(fill=tk.X, padx=4, pady=4)

        title_box = tk.Frame(topbar, bg=self.XAW_BG)
        title_box.pack(side=tk.LEFT, padx=4)

        self.lbl_day_title = tk.Label(
            title_box,
            text=f"[ XAW::JIRA_LOG ]  {self.selected_day}",
            font=self.FONT_TITLE,
            bg=self.XAW_BG,
            fg=self.XAW_BLACK
        )
        self.lbl_day_title.pack(side=tk.LEFT)

        self.lbl_loading = tk.Label(
            title_box,
            text="",
            fg="#aa0000",
            bg=self.XAW_BG,
            font=self.FONT_BOLD
        )
        self.lbl_loading.pack(side=tk.LEFT, padx=14)

        nav_box = tk.Frame(topbar, bg=self.XAW_BG)
        nav_box.pack(side=tk.RIGHT, padx=4)

        self.create_xaw_button(nav_box, "< Dia anterior", self.go_prev_day).pack(side=tk.LEFT, padx=2)
        self.create_xaw_button(nav_box, "[ Hoy ]", self.go_today).pack(side=tk.LEFT, padx=2)
        self.btn_next = self.create_xaw_button(nav_box, "Dia siguiente >", self.go_next_day)
        self.btn_next.pack(side=tk.LEFT, padx=2)
        self.create_xaw_button(nav_box, "[!] Sincronizar", self.refresh_all_async, highlight=True).pack(side=tk.LEFT, padx=6)

        # 2. Contenedor principal dividido
        main_box = tk.Frame(self, bg=self.XAW_BG)
        main_box.pack(fill=tk.BOTH, expand=True, padx=4, pady=2)

        # Panel Izquierdo: Resumen y Formulario Athena
        self.left_frame = tk.Frame(main_box, bg=self.XAW_PANEL_BG, bd=2, relief=tk.SOLID, padx=8, pady=8, width=370)
        self.left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 4))
        self.left_frame.pack_propagate(False)

        # Panel Derecho: Tablas y Filtros
        self.right_frame = tk.Frame(main_box, bg=self.XAW_BG, bd=2, relief=tk.SOLID, padx=6, pady=6)
        self.right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.build_right_panel(self.right_frame)
        self.build_left_panel()

        # 3. Barra inferior Xaw
        bottom_bar = tk.Frame(self, bg=self.XAW_BG, bd=2, relief=tk.SOLID, padx=6, pady=4)
        bottom_bar.pack(fill=tk.X, padx=4, pady=4)

        self.create_xaw_button(bottom_bar, "[*] Ver Detalle Dia (Imprimir PDF / Abrir Jira)", self.show_day_detail, highlight=True).pack(side=tk.LEFT, padx=2)
        self.create_xaw_button(bottom_bar, "[X] Salir", self.destroy).pack(side=tk.RIGHT, padx=2)

    def build_left_panel(self):
        for widget in self.left_frame.winfo_children():
            widget.destroy()

        # Marco Totales
        totals_box = tk.LabelFrame(
            self.left_frame,
            text=" TOTALES_JORNADA ",
            bg=self.XAW_PANEL_BG,
            fg=self.XAW_BLACK,
            font=self.FONT_BOLD,
            bd=2,
            relief=tk.SOLID,
            padx=8,
            pady=6
        )
        totals_box.pack(fill=tk.X, pady=(0, 8))

        self.lbl_total_hours = tk.Label(totals_box, text="0 h", font=self.FONT_BIG, fg=self.XAW_BLACK, bg=self.XAW_PANEL_BG)
        self.lbl_total_hours.pack(anchor="w")

        self.lbl_sub_hours = tk.Label(totals_box, text="Jira: 0 h | Local: 0 h", font=self.FONT_MAIN, fg=self.XAW_BLACK, bg=self.XAW_PANEL_BG)
        self.lbl_sub_hours.pack(anchor="w", pady=(2, 2))

        self.lbl_status = tk.Label(totals_box, text="Faltan 8 h", font=self.FONT_BOLD, fg="#880000", bg=self.XAW_PANEL_BG)
        self.lbl_status.pack(anchor="w", pady=(2, 2))

        is_today = (self.selected_day == date.today().isoformat())
        curr_state = day_state(self.state, self.selected_day)

        if is_today:
            is_story_mode = (self.active_selection_type == "story")
            selected_item = self.get_selected_issue()
            item_summary = f"{selected_item['key']} [{selected_item.get('type')}]" if selected_item else "(ninguno)"

            if is_story_mode:
                form_box = tk.LabelFrame(
                    self.left_frame,
                    text=" MODO::HISTORIA_DE_USUARIO ",
                    bg=self.XAW_PANEL_BG,
                    fg=self.XAW_BLACK,
                    font=self.FONT_BOLD,
                    bd=2,
                    relief=tk.SOLID,
                    padx=6,
                    pady=6
                )
                form_box.pack(fill=tk.BOTH, expand=True)

                tk.Label(
                    form_box,
                    text="Crea una tarea vinculada a la historia seleccionada.",
                    font=self.FONT_MAIN,
                    fg="#222222",
                    bg=self.XAW_PANEL_BG,
                    wraplength=330,
                    justify=tk.LEFT
                ).pack(anchor="w", pady=(0, 6))

                tk.Label(
                    form_box,
                    text=f"HU: {item_summary}",
                    font=self.FONT_BOLD,
                    fg=self.XAW_BLACK,
                    bg=self.XAW_PANEL_BG,
                    wraplength=330,
                    justify=tk.LEFT
                ).pack(anchor="w", pady=(0, 6))

                # Tiempo
                time_row = tk.Frame(form_box, bg=self.XAW_PANEL_BG)
                time_row.pack(fill=tk.X, pady=3)

                tk.Label(time_row, text="Tiempo:", bg=self.XAW_PANEL_BG, font=self.FONT_BOLD).pack(side=tk.LEFT)
                self.story_qty_var = tk.StringVar(value=str(curr_state.get("selected", 1.0)))
                qty_menu = tk.OptionMenu(time_row, self.story_qty_var, "0.5", "1.0", "1.5", "2.0", "2.5", "3.0", "4.0", "8.0")
                qty_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
                qty_menu.pack(side=tk.LEFT, padx=4)

                tk.Label(time_row, text="Horas", bg=self.XAW_PANEL_BG, font=self.FONT_MAIN).pack(side=tk.LEFT)

                # Ceremonia
                tk.Label(form_box, text="Ceremonia / Actividad:", bg=self.XAW_PANEL_BG, font=self.FONT_BOLD).pack(anchor="w", pady=(6, 2))
                self.story_act_var = tk.StringVar(value=curr_state.get("activity", "Refinamiento"))
                if self.story_act_var.get() not in ["Refinamiento", "Planning", "Retrospectiva", "Adicional"]:
                    self.story_act_var.set("Refinamiento")
                act_menu = tk.OptionMenu(form_box, self.story_act_var, "Refinamiento", "Planning", "Retrospectiva", "Adicional")
                act_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
                act_menu.pack(fill=tk.X, pady=(0, 6))

                # Detalle
                tk.Label(form_box, text="Detalle de tarea:", bg=self.XAW_PANEL_BG, font=self.FONT_BOLD).pack(anchor="w", pady=(4, 2))
                self.entry_detail = tk.Entry(form_box, bg=self.XAW_WHITE, fg=self.XAW_BLACK, bd=1, relief=tk.SOLID, font=self.FONT_MAIN)
                self.entry_detail.pack(fill=tk.X, pady=(0, 10))

                self.create_xaw_button(form_box, "[>>] Crear tarea y registrar en Jira", self.register_direct_jira, highlight=True).pack(fill=tk.X, pady=3)
                self.create_xaw_button(form_box, "[+] Preparar registro local", self.insert_local_work).pack(fill=tk.X, pady=3)

            else:
                form_box = tk.LabelFrame(
                    self.left_frame,
                    text=" MODO::REGISTRO_TAREA ",
                    bg=self.XAW_PANEL_BG,
                    fg=self.XAW_BLACK,
                    font=self.FONT_BOLD,
                    bd=2,
                    relief=tk.SOLID,
                    padx=6,
                    pady=6
                )
                form_box.pack(fill=tk.BOTH, expand=True)

                tk.Label(
                    form_box,
                    text=f"Tarea: {item_summary}",
                    font=self.FONT_BOLD,
                    fg=self.XAW_BLACK,
                    bg=self.XAW_PANEL_BG,
                    wraplength=330,
                    justify=tk.LEFT
                ).pack(anchor="w", pady=(0, 8))

                time_row = tk.Frame(form_box, bg=self.XAW_PANEL_BG)
                time_row.pack(fill=tk.X, pady=6)

                tk.Label(time_row, text="Cantidad:", bg=self.XAW_PANEL_BG, font=self.FONT_BOLD).pack(side=tk.LEFT)
                self.task_qty_var = tk.StringVar(value=str(int(float(curr_state.get("selected", 1)))))
                self.task_qty_menu = tk.OptionMenu(time_row, self.task_qty_var, "1", "2", "3", "4", "5", "6", "7", "8")
                self.task_qty_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
                self.task_qty_menu.pack(side=tk.LEFT, padx=4)

                self.task_unit_var = tk.StringVar(value=curr_state.get("unit", "Horas"))
                unit_menu = tk.OptionMenu(time_row, self.task_unit_var, "Horas", "Minutos", command=self.on_xaw_unit_change)
                unit_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
                unit_menu.pack(side=tk.LEFT, padx=4)

                self.create_xaw_button(form_box, "[>>] INSERTAR EN JIRA DIRECTO", self.register_direct_jira, highlight=True).pack(fill=tk.X, pady=(12, 4))
                self.create_xaw_button(form_box, "[+] Guardar en cola local", self.insert_local_work).pack(fill=tk.X, pady=4)
        else:
            hist_box = tk.LabelFrame(
                self.left_frame,
                text=" HISTORIAL ",
                bg=self.XAW_PANEL_BG,
                fg=self.XAW_BLACK,
                font=self.FONT_BOLD,
                bd=2,
                relief=tk.SOLID,
                padx=6,
                pady=6
            )
            hist_box.pack(fill=tk.BOTH, expand=True)
            tk.Label(hist_box, text=f"Fecha: {self.selected_day}", font=self.FONT_BOLD, bg=self.XAW_PANEL_BG).pack(anchor="w", pady=4)
            tk.Label(hist_box, text=f"{format_date_es(self.selected_day)}", font=self.FONT_MAIN, bg=self.XAW_PANEL_BG).pack(anchor="w")

    def on_xaw_unit_change(self, val):
        menu = self.task_qty_menu["menu"]
        menu.delete(0, "end")
        if val == "Minutos":
            for opt in ["15", "30", "45", "60", "90", "120"]:
                menu.add_command(label=opt, command=lambda v=opt: self.task_qty_var.set(v))
            self.task_qty_var.set("30")
        else:
            for opt in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]:
                menu.add_command(label=opt, command=lambda v=opt: self.task_qty_var.set(v))
            self.task_qty_var.set("1")

    def build_right_panel(self, parent):
        # Barra de Filtros
        filter_box = tk.Frame(parent, bg=self.XAW_BG, bd=1, relief=tk.SOLID, padx=4, pady=3)
        filter_box.pack(fill=tk.X, pady=(0, 4))

        self.controls_bar = tk.Frame(filter_box, bg=self.XAW_BG)
        self.controls_bar.pack(fill=tk.X)

        tk.Label(self.controls_bar, text="PROYECTO:", font=self.FONT_BOLD, bg=self.XAW_BG).pack(side=tk.LEFT, padx=(0, 2))
        self.project_var = tk.StringVar(value="Todos los proyectos")
        self.project_menu = tk.OptionMenu(self.controls_bar, self.project_var, "Todos los proyectos", command=self.on_project_select)
        self.project_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
        self.project_menu.pack(side=tk.LEFT, padx=(0, 8))

        tk.Label(self.controls_bar, text="PARENT:", font=self.FONT_BOLD, bg=self.XAW_BG).pack(side=tk.LEFT, padx=(0, 2))
        self.parent_var = tk.StringVar(value="Todos los parents")
        self.parent_menu = tk.OptionMenu(self.controls_bar, self.parent_var, "Todos los parents", command=self.on_parent_select)
        self.parent_menu.config(bg="#d8d8d8", bd=1, relief=tk.SOLID, highlightthickness=1, font=self.FONT_MAIN)
        self.parent_menu.pack(side=tk.LEFT, padx=(0, 8))

        self.entry_search = tk.Entry(self.controls_bar, width=14, bg=self.XAW_WHITE, fg=self.XAW_BLACK, bd=1, relief=tk.SOLID, font=self.FONT_MAIN)
        self.entry_search.pack(side=tk.RIGHT)
        self.entry_search.bind("<KeyRelease>", self.on_search)

        tk.Label(self.controls_bar, text="BUSCAR:", font=self.FONT_BOLD, bg=self.XAW_BG).pack(side=tk.RIGHT, padx=(0, 2))

        # SECCIÓN SUPERIOR: TAREAS
        self.upper_frame = tk.Frame(parent, bg=self.XAW_BG)
        self.upper_frame.pack(fill=tk.BOTH, expand=True, pady=(2, 2))

        upper_header = tk.Frame(self.upper_frame, bg=self.XAW_BG)
        upper_header.pack(fill=tk.X, pady=(0, 2))

        self.lbl_tasks_header = tk.Label(upper_header, text="-- [ TAREAS ASIGNADAS ] --------------------------------", font=self.FONT_BOLD, bg=self.XAW_BG, fg=self.XAW_BLACK)
        self.lbl_tasks_header.pack(side=tk.LEFT)

        self.btn_clear_story = self.create_xaw_button(upper_header, "[ Ver todas ]", self.clear_story_selection)
        self.btn_clear_story.pack(side=tk.RIGHT)

        tasks_box = tk.Frame(self.upper_frame, bg=self.XAW_BG, bd=1, relief=tk.SOLID)
        tasks_box.pack(fill=tk.BOTH, expand=True)

        self.list_tasks = tk.Listbox(
            tasks_box,
            font=self.FONT_MAIN,
            bg=self.XAW_WHITE,
            fg=self.XAW_BLACK,
            selectbackground=self.XAW_SEL_BG,
            selectforeground=self.XAW_SEL_FG,
            activestyle="none",
            bd=0,
            highlightthickness=0
        )
        self.scroll_tasks = XawScrollbar(tasks_box, command=self.list_tasks.yview)
        self.list_tasks.config(yscrollcommand=self.scroll_tasks.set)

        self.list_tasks.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.scroll_tasks.pack(side=tk.RIGHT, fill=tk.Y)

        self.list_tasks.bind("<<ListboxSelect>>", self.on_task_select)
        self.list_tasks.bind("<Double-1>", self.on_task_double_click)

        # SECCIÓN INFERIOR: HISTORIAS DE USUARIO
        self.lower_frame = tk.Frame(parent, bg=self.XAW_BG)
        self.lower_frame.pack(fill=tk.BOTH, expand=True, pady=(4, 0))

        lower_header = tk.Frame(self.lower_frame, bg=self.XAW_BG)
        lower_header.pack(fill=tk.X, pady=(0, 2))

        self.lbl_stories_header = tk.Label(lower_header, text="-- [ HISTORIAS DE USUARIO ] -----------------------------", font=self.FONT_BOLD, bg=self.XAW_BG, fg=self.XAW_BLACK)
        self.lbl_stories_header.pack(side=tk.LEFT)

        stories_box = tk.Frame(self.lower_frame, bg=self.XAW_BG, bd=1, relief=tk.SOLID)
        stories_box.pack(fill=tk.BOTH, expand=True)

        self.list_stories = tk.Listbox(
            stories_box,
            font=self.FONT_MAIN,
            bg=self.XAW_WHITE,
            fg=self.XAW_BLACK,
            selectbackground=self.XAW_SEL_BG,
            selectforeground=self.XAW_SEL_FG,
            activestyle="none",
            bd=0,
            highlightthickness=0
        )
        self.scroll_stories = XawScrollbar(stories_box, command=self.list_stories.yview)
        self.list_stories.config(yscrollcommand=self.scroll_stories.set)

        self.list_stories.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.scroll_stories.pack(side=tk.RIGHT, fill=tk.Y)

        self.list_stories.bind("<<ListboxSelect>>", self.on_story_select)
        self.list_stories.bind("<Double-1>", self.on_story_double_click)

    def on_task_select(self, event=None):
        sel = self.list_tasks.curselection()
        if sel:
            self.active_selection_type = "task"
            self.build_left_panel()

    def on_story_select(self, event=None):
        sel = self.list_stories.curselection()
        if sel:
            idx = sel[0]
            if hasattr(self, "_displayed_stories") and idx < len(self._displayed_stories):
                story = self._displayed_stories[idx]
                self.selected_story_key = story["key"]
                self.active_selection_type = "story"
                self.build_left_panel()
                self.render_tasks_table()

    def clear_story_selection(self):
        self.selected_story_key = None
        self.list_stories.selection_clear(0, tk.END)
        self.active_selection_type = "task"
        self.build_left_panel()
        self.render_tasks_table()

    def on_project_select(self, val):
        self.selected_project = val
        self.selected_parent = "Todos los parents"
        self.selected_story_key = None
        self.update_parent_dropdown()
        self.render_table()

    def on_parent_select(self, val):
        self.selected_parent = val
        self.selected_story_key = None
        self.render_table()

    def update_project_dropdown(self):
        projects_ordered = []
        for it in self.issues:
            p = it.get("project")
            if p and p != "-" and p not in projects_ordered:
                projects_ordered.append(p)

        options = ["Todos los proyectos"] + projects_ordered
        menu = self.project_menu["menu"]
        menu.delete(0, "end")
        for opt in options:
            menu.add_command(label=opt, command=lambda v=opt: (self.project_var.set(v), self.on_project_select(v)))

        if projects_ordered and (self.selected_project == "Todos los proyectos" or self.selected_project not in options):
            self.selected_project = projects_ordered[0]

        self.project_var.set(self.selected_project)
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
        menu = self.parent_menu["menu"]
        menu.delete(0, "end")
        for opt in options:
            menu.add_command(label=opt, command=lambda v=opt: (self.parent_var.set(v), self.on_parent_select(v)))

        if parents_ordered and (self.selected_parent == "Todos los parents" or self.selected_parent not in options):
            self.selected_parent = parents_ordered[0]
        elif not parents_ordered:
            self.selected_parent = "Todos los parents"

        self.parent_var.set(self.selected_parent)

    def update_totals_ui(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        jira_total = sum(float(item.get("hours", 0)) for item in jira_worklogs)
        local_total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total = jira_total + local_total
        min_hours = 6.5
        max_hours = 10.5

        self.lbl_day_title.config(text=f"[ XAW::JIRA_LOG ]  {self.selected_day}")
        self.lbl_total_hours.config(text=format_hours(total))
        self.lbl_sub_hours.config(text=f"Jira: {format_hours(jira_total)} | Local: {format_hours(local_total)}")

        if total < min_hours:
            diff_min = min_hours - total
            self.lbl_status.config(text=f"Faltan minimo {format_hours(diff_min)}", fg="#880000")
        elif total <= max_hours:
            self.lbl_status.config(text="[OK] Jornada completa", fg="#006600")
        else:
            diff_over = total - max_hours
            self.lbl_status.config(text=f"[!] Sobrepaso: {format_hours(diff_over)}", fg="#880000")

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

            self.list_tasks.delete(0, tk.END)
            curr_state = day_state(self.state, self.selected_day)
            jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
            historical = [*jira_worklogs, *curr_state.get("worklogs", [])]

            self.lbl_tasks_header.config(text=f"-- [ HISTORIAL ({len(historical)} reg) ] ---------------------------")
            self._displayed_tasks = []

            for item in historical:
                text_to_search = f"{item.get('key', '')} {item.get('story', '')} {item.get('summary', '')}".lower()
                if query and query not in text_to_search:
                    continue
                k = item.get("key", "-").ljust(12)
                h = format_hours(item.get("hours", 0)).rjust(8)
                sum_text = (item.get("summary") or "")[:70]
                line = f"{k} | {h} | {sum_text}"
                self.list_tasks.insert(tk.END, line)
                self._displayed_tasks.append(item)

    def render_tasks_table(self):
        self.list_tasks.delete(0, tk.END)
        query = self.search_filter.lower().strip()

        tasks_list = [it for it in self.issues if it.get("type") not in ("Historia de usuario", "Story", "Historia")]
        selected_story = next((it for it in self.issues if it["key"] == self.selected_story_key), None) if self.selected_story_key else None
        story_linked_task_keys = set(selected_story.get("linked_tasks", [])) if selected_story else set()

        filtered = []
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
            filtered.append(task)

        if self.selected_story_key:
            self.lbl_tasks_header.config(text=f"-- [ TAREAS DE {self.selected_story_key} ({len(filtered)}) ] --------------------")
        else:
            self.lbl_tasks_header.config(text=f"-- [ TAREAS ASIGNADAS ({len(filtered)}) ] ------------------------")

        self._displayed_tasks = filtered
        for t in filtered:
            k = t["key"].ljust(12)
            st = t.get("status", "Sin estado")[:14].ljust(15)
            h = t.get("hours", "0 h").rjust(8)
            sum_text = t.get("summary", "")[:68]
            line = f"{k} | {st} | {h} | {sum_text}"
            self.list_tasks.insert(tk.END, line)

    def render_stories_table(self):
        self.list_stories.delete(0, tk.END)
        query = self.search_filter.lower().strip()

        stories_list = [it for it in self.issues if it.get("type") in ("Historia de usuario", "Story", "Historia")]
        filtered = []
        for story in stories_list:
            if self.selected_project != "Todos los proyectos" and story.get("project") != self.selected_project:
                continue
            if self.selected_parent != "Todos los parents" and story.get("parent") != self.selected_parent:
                continue
            text_to_search = f"{story['key']} {story['project']} {story['parent']} {story['summary']} {story['status']}".lower()
            if query and query not in text_to_search:
                continue
            filtered.append(story)

        self.lbl_stories_header.config(text=f"-- [ HISTORIAS DE USUARIO ({len(filtered)}) ] ---------------------")
        self._displayed_stories = filtered
        for idx, s in enumerate(filtered):
            k = s["key"].ljust(12)
            st = s.get("status", "Sin estado")[:14].ljust(15)
            sum_text = s.get("summary", "")[:78]
            line = f"{k} | {st} | {sum_text}"
            self.list_stories.insert(tk.END, line)
            if self.selected_story_key and s["key"] == self.selected_story_key:
                self.list_stories.selection_set(idx)

    def on_search(self, event=None):
        self.search_filter = self.entry_search.get()
        self.render_table()

    def get_selected_issue(self):
        if self.active_selection_type == "story":
            sel = self.list_stories.curselection()
            if sel and hasattr(self, "_displayed_stories") and sel[0] < len(self._displayed_stories):
                return self._displayed_stories[sel[0]]
        else:
            sel = self.list_tasks.curselection()
            if sel and hasattr(self, "_displayed_tasks") and sel[0] < len(self._displayed_tasks):
                return self._displayed_tasks[sel[0]]
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
            messagebox.showwarning("Aviso", "Selecciona una tarea o historia de la lista.")
            return

        is_story = (self.active_selection_type == 'story')
        if is_story:
            try:
                amount = float(self.story_qty_var.get())
            except Exception:
                amount = 1.0
            unit = "Horas"
        else:
            try:
                amount = float(self.task_qty_var.get())
            except Exception:
                amount = 1.0
            unit = self.task_unit_var.get()

        hours = amount / 60.0 if unit == "Minutos" else amount
        curr_state = day_state(self.state, self.selected_day)
        curr_state["selected"] = amount
        curr_state["unit"] = unit

        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total += sum(float(item.get("hours", 0)) for item in jira_worklogs)

        if total + hours > 10.5:
            messagebox.showwarning("Maximo diario", "El registro superaria el maximo diario de 10 h 30 min.")
            return

        activity = self.story_act_var.get() if (is_story and hasattr(self, 'story_act_var')) else "Trabajo en tarea"
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
        messagebox.showinfo("OK", f"Se anadieron {format_hours(hours)} a {issue['key']} en cola local.")

    def register_direct_jira(self):
        issue = self.get_selected_issue()
        if not issue:
            messagebox.showwarning("Aviso", "Selecciona una tarea o historia de la lista.")
            return

        is_story = (issue.get("type") in ("Historia de usuario", "Story", "Historia"))
        if is_story:
            try:
                amount = float(self.story_qty_var.get())
            except Exception:
                amount = 1.0
            unit = "Horas"
        else:
            try:
                amount = float(self.task_qty_var.get())
            except Exception:
                amount = 1.0
            unit = self.task_unit_var.get()

        hours = amount / 60.0 if unit == "Minutos" else amount
        activity = self.story_act_var.get() if (is_story and hasattr(self, 'story_act_var')) else "Trabajo en tarea"
        detail = self.entry_detail.get().strip() if (is_story and hasattr(self, 'entry_detail')) else ""
        if not detail:
            detail = activity if is_story else issue["summary"]

        if is_story:
            prompt_text = (
                f"[HISTORIA DE USUARIO]\n\n"
                f"Se creara una nueva TAREA en Jira:\n"
                f"• Resumen: '{activity}: {detail}'\n"
                f"• Vinculada a: {issue['key']} - {issue['summary']}\n"
                f"• Tiempo: {format_hours(hours)}\n\n"
                f"¿Confirmas el registro?"
            )
        else:
            prompt_text = (
                f"¿Deseas registrar en Jira?\n\n"
                f"Tarea: {issue['key']}\n"
                f"Tiempo: {format_hours(hours)}\n"
                f"Descripcion: {issue['summary']}"
            )

        if not messagebox.askyesno("Confirmar Jira", prompt_text):
            return

        self.set_loading(True, "Registrando en Jira...")

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
                    msg = f"¡{target_key} registrada con exito ({format_hours(hours)})!\n\n¿Abrir en navegador?"
                    if messagebox.askyesno("Exito", msg):
                        webbrowser.open(url)

                self.after(0, on_success)
            except Exception as err:
                def on_fail():
                    self.set_loading(False)
                    LOG.exception("Error al registrar en Jira")
                    messagebox.showerror("Error Jira", str(err))

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
        self.lbl_loading.config(text=f"[ {text} ]" if loading else "")
        self.update_idletasks()

    def fetch_day_worklogs_async(self, target_day):
        self.set_loading(True, f"Cargando {target_day}...")

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
        self.set_loading(True, "Sincronizando Jira...")

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
                    messagebox.showerror("Error Jira", err_msg)

                self.after(0, on_error)

        threading.Thread(target=task, daemon=True).start()

    def show_day_detail(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        all_rows = [*jira_worklogs, *curr_state.get("worklogs", [])]

        win = tk.Toplevel(self)
        win.title(f"Detalle [{self.selected_day}]")
        win.geometry("1050x500")
        win.configure(bg=self.XAW_BG)

        header = tk.Frame(win, bg=self.XAW_BG, bd=2, relief=tk.SOLID, padx=6, pady=4)
        header.pack(fill=tk.X, padx=4, pady=4)
        tk.Label(header, text=f"DETALLE DE REGISTROS - {format_date_es(self.selected_day)}", font=self.FONT_BOLD, bg=self.XAW_BG).pack(anchor="w")

        tree_box = tk.Frame(win, bg=self.XAW_BG, bd=1, relief=tk.SOLID)
        tree_box.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)

        listbox = tk.Listbox(
            tree_box,
            font=self.FONT_MAIN,
            bg=self.XAW_WHITE,
            fg=self.XAW_BLACK,
            selectbackground=self.XAW_SEL_BG,
            selectforeground=self.XAW_SEL_FG,
            activestyle="none",
            bd=0,
            highlightthickness=0
        )
        scroll = XawScrollbar(tree_box, command=listbox.yview)
        listbox.config(yscrollcommand=scroll.set)

        for it in all_rows:
            k = it.get("key", "-").ljust(12)
            h = format_hours(it.get("hours", 0)).rjust(8)
            st = (it.get("story") or "-")[:35].ljust(36)
            sm = (it.get("summary") or "")[:55]
            listbox.insert(tk.END, f"{k} | {h} | {st} | {sm}")

        listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)

        def open_selected(event=None):
            sel = listbox.curselection()
            if sel and sel[0] < len(all_rows):
                k = all_rows[sel[0]].get("key")
                if k and k != "—":
                    domain = self.config_data.get("JIRA_DOMAIN", "").rstrip("/")
                    webbrowser.open(f"{domain}/browse/{k}")

        listbox.bind("<Double-1>", open_selected)

        btn_bar = tk.Frame(win, bg=self.XAW_BG, bd=2, relief=tk.SOLID, padx=6, pady=4)
        btn_bar.pack(fill=tk.X, padx=4, pady=4)

        def print_pdf():
            if not all_rows:
                messagebox.showwarning("Sin registros", "No hay registros para generar PDF.")
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

        self.create_xaw_button(btn_bar, "[>>] Imprimir PDF (1 pag/reg)", print_pdf, highlight=True).pack(side=tk.LEFT, padx=3)
        self.create_xaw_button(btn_bar, "[^] Abrir en Jira", open_selected).pack(side=tk.LEFT, padx=3)
        self.create_xaw_button(btn_bar, "[X] Cerrar", win.destroy).pack(side=tk.RIGHT, padx=3)


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

    LOG.info("Inicio de la aplicacion con frontend Xaw / Athena")
    if not os.path.exists(CONFIG):
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror("Falta configuracion", f"No existe el archivo de configuracion en:\n{CONFIG}")
        return 1

    try:
        config = read_config()
    except Exception as error:
        root = tk.Tk()
        root.withdraw()
        LOG.exception("Error al leer configuracion")
        messagebox.showerror("Error de configuracion", str(error))
        return 1

    app = RegistroDiarioXawApp(config)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
