#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
registro-diario-broadwayd.py - Port idéntico al 100% de registro-diario.py a GTK3 nativo.
Soporta ejecución directa en X11 o en navegador vía Broadway (GDK_BACKEND=broadway).
Todos los controles, dropdowns, diálogos, atajos y flujos son idénticos a la versión original.
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

# Auto-lanzador Broadway si no está definido el backend
BROADWAY_PORT = 8085
BROADWAY_DISPLAY_NUM = 5

if "GDK_BACKEND" not in os.environ:
    # 1. Asegurar que broadwayd esté corriendo en el puerto configurado
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{BROADWAY_PORT}", timeout=0.5)
    except Exception:
        subprocess.Popen(["broadwayd", f"--port={BROADWAY_PORT}", f":{BROADWAY_DISPLAY_NUM}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)

    # 2. Re-ejecutar con variables de entorno de broadway
    env = os.environ.copy()
    env["GDK_BACKEND"] = "broadway"
    env["BROADWAY_DISPLAY"] = f":{BROADWAY_DISPLAY_NUM}"

    try:
        subprocess.Popen(["google-chrome-stable", f"http://localhost:{BROADWAY_PORT}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        webbrowser.open(f"http://localhost:{BROADWAY_PORT}")

    os.execvpe(sys.executable, [sys.executable, __file__] + sys.argv[1:], env)

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GLib
from PIL import Image

CONFIG = os.path.expanduser("~/.justificar/jira_config")
CSV = os.path.expanduser("~/.justificar/justificar.csv")
STATE_FILE = os.path.expanduser("~/.justificar/registro-diario-yad.json")
LOG_FILE = os.path.expanduser("~/.justificar/registro-diario-broadwayd.log")


def setup_logging():
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logger = logging.getLogger("registro-diario-broadwayd")
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
        except Exception:
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
        return
    except RuntimeError as error:
        if "401" not in str(error):
            raise
    tenant_url = config["JIRA_DOMAIN"].rstrip("/") + "/_edge/tenant_info"
    try:
        with urllib.request.urlopen(tenant_url, timeout=15) as response:
            cloud_id = json.loads(response.read().decode()).get("cloudId")
    except Exception as error:
        raise RuntimeError("No se pudo obtener cloudId de Jira.") from error
    if not cloud_id:
        raise RuntimeError("Jira no devolvió un cloudId válido.")
    config["_API_BASE"] = f"https://api.atlassian.com/ex/jira/{cloud_id}"
    me = jira(config, "/rest/api/3/myself")
    config["_ACCOUNT_ID"] = me.get("accountId")


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

    query_tasks = urllib.parse.urlencode({"jql": jql_tasks, "maxResults": 100, "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks"})
    query_stories = urllib.parse.urlencode({"jql": jql_stories, "maxResults": 200, "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks"})
    query_stories_fallback = urllib.parse.urlencode({"jql": jql_stories_fallback, "maxResults": 100, "fields": "key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks"})

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
            pass

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
        except Exception:
            return []

    records = []
    with ThreadPoolExecutor(max_workers=min(8, len(issues_list))) as executor:
        for res in executor.map(fetch_worklogs_for_issue, issues_list):
            records.extend(res)

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
    return f"{days_es[d.weekday()]}, {d.day} de {months_es[d.month - 1]} de {d.year}"


# ==============================================================================
# APLICACIÓN GTK3 REPLICANDO FIELMENTE TODOS LOS CONTROLES DE REGISTRO-DIARIO.PY
# ==============================================================================
class RegistroDiarioGtkApp(Gtk.Window):
    def __init__(self, config):
        super().__init__(title="Horas · Registro diario [Broadway]")
        self.config_data = config
        self.state = load_state()
        self.selected_day = date.today().isoformat()
        self.issues = []
        self.jira_worklogs_cache = {}
        self.search_filter = ""
        self.selected_project = "Todos los proyectos"
        self.selected_parent = "Todos los parents"
        self.selected_story_key = None
        self.active_selection_type = "task"  # 'task' | 'story'

        self.set_default_size(1400, 820)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.maximize()
        self.connect("destroy", Gtk.main_quit)

        self.setup_styles()
        self.build_ui()
        self.refresh_all_async()

    def setup_styles(self):
        css_provider = Gtk.CssProvider()
        css = b"""
        window {
            background-color: #f4f5f9;
            color: #1e293b;
            font-family: "Noto Sans", sans-serif;
            font-size: 13px;
        }
        .header-top {
            background-color: #f4f5f9;
            padding: 8px 16px;
        }
        .card-left {
            background-color: #ffffff;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            padding: 16px;
        }
        .big-total {
            font-size: 26px;
            font-weight: bold;
            color: #2563eb;
        }
        .btn-primary {
            background-color: #2563eb;
            color: #ffffff;
            font-weight: bold;
            border-radius: 6px;
            padding: 7px 12px;
            border: none;
        }
        .btn-primary:hover {
            background-color: #1d4ed8;
        }
        .btn-secondary {
            background-color: #e2e8f0;
            color: #1e293b;
            border-radius: 6px;
            padding: 6px 10px;
            border: none;
        }
        .btn-secondary:hover {
            background-color: #cbd5e1;
        }
        treeview {
            background-color: #ffffff;
            color: #1e293b;
        }
        treeview:selected {
            background-color: #dbeafe;
            color: #1e3a8a;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def build_ui(self):
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.add(main_vbox)

        # 1. Header Top bar
        top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        top_bar.get_style_context().add_class("header-top")
        main_vbox.pack_start(top_bar, False, False, 0)

        self.lbl_day_title = Gtk.Label()
        self.lbl_day_title.set_markup(f"<b><big>Resumen de {self.selected_day}</big></b>")
        top_bar.pack_start(self.lbl_day_title, False, False, 0)

        self.lbl_loading = Gtk.Label(label="")
        top_bar.pack_start(self.lbl_loading, False, False, 16)

        nav_frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        top_bar.pack_end(nav_frame, False, False, 0)

        btn_prev = Gtk.Button(label="← Día anterior")
        btn_prev.get_style_context().add_class("btn-secondary")
        btn_prev.connect("clicked", lambda w: self.go_prev_day())
        nav_frame.pack_start(btn_prev, False, False, 0)

        btn_today = Gtk.Button(label="Hoy")
        btn_today.get_style_context().add_class("btn-secondary")
        btn_today.connect("clicked", lambda w: self.go_today())
        nav_frame.pack_start(btn_today, False, False, 0)

        self.btn_next = Gtk.Button(label="Día siguiente →")
        self.btn_next.get_style_context().add_class("btn-secondary")
        self.btn_next.connect("clicked", lambda w: self.go_next_day())
        nav_frame.pack_start(self.btn_next, False, False, 0)

        btn_refresh = Gtk.Button(label="🔄 Actualizar Jira")
        btn_refresh.get_style_context().add_class("btn-secondary")
        btn_refresh.connect("clicked", lambda w: self.refresh_all_async())
        nav_frame.pack_start(btn_refresh, False, False, 6)

        # 2. Main Paned Layout
        main_pane = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        main_pane.set_position(380)
        main_vbox.pack_start(main_pane, True, True, 4)

        # Panel Izquierdo
        self.left_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.left_frame.get_style_context().add_class("card-left")
        self.left_frame.set_margin_start(16)
        self.left_frame.set_margin_bottom(6)
        self.left_frame.set_size_request(380, -1)
        main_pane.pack1(self.left_frame, False, False)

        # Panel Derecho
        self.right_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.right_frame.set_margin_end(16)
        self.right_frame.set_margin_bottom(6)
        main_pane.pack2(self.right_frame, True, False)

        self.build_right_panel()
        self.build_left_panel()

        # 3. Barra inferior
        bottom_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bottom_bar.set_margin_start(16)
        bottom_bar.set_margin_end(16)
        bottom_bar.set_margin_bottom(8)
        main_vbox.pack_start(bottom_bar, False, False, 0)

        btn_summary = Gtk.Button(label="Ver Detalle Día")
        btn_summary.get_style_context().add_class("btn-secondary")
        btn_summary.connect("clicked", lambda w: self.show_day_detail())
        bottom_bar.pack_start(btn_summary, False, False, 0)

        btn_close = Gtk.Button(label="Cerrar")
        btn_close.get_style_context().add_class("btn-secondary")
        btn_close.connect("clicked", lambda w: self.destroy())
        bottom_bar.pack_end(btn_close, False, False, 0)

    def build_left_panel(self):
        for child in self.left_frame.get_children():
            self.left_frame.remove(child)

        self.lbl_total_hours = Gtk.Label(label="0 h", xalign=0)
        self.lbl_total_hours.get_style_context().add_class("big-total")
        self.left_frame.pack_start(self.lbl_total_hours, False, False, 0)

        self.lbl_sub_hours = Gtk.Label(label="Jira: 0 h · Preparadas: 0 h", xalign=0)
        self.left_frame.pack_start(self.lbl_sub_hours, False, False, 0)

        self.lbl_status = Gtk.Label(label="Faltan 8 h", xalign=0)
        self.left_frame.pack_start(self.lbl_status, False, False, 2)

        self.left_frame.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 6)

        is_today = (self.selected_day == date.today().isoformat())
        curr_state = day_state(self.state, self.selected_day)

        if is_today:
            selected_item = self.get_selected_issue()
            if not selected_item:
                lbl_hint_title = Gtk.Label(label="<b>Registro de horas</b>", use_markup=True, xalign=0)
                self.left_frame.pack_start(lbl_hint_title, False, False, 0)
                lbl_hint = Gtk.Label(
                    label="Selecciona una tarea o una historia de usuario de la lista de la derecha para habilitar los controles de tiempo e inserción.",
                    wrap=True, xalign=0
                )
                self.left_frame.pack_start(lbl_hint, False, False, 4)
            else:
                is_story_mode = (self.active_selection_type == "story")
                item_summary = f"{selected_item['key']} ({selected_item.get('type')})"

                if is_story_mode:
                    lbl_form_title = Gtk.Label(label="<b>📖 Registro para Historia</b>", use_markup=True, xalign=0)
                    self.left_frame.pack_start(lbl_form_title, False, False, 0)

                    lbl_form_sub = Gtk.Label(
                        label="Al registrar en una Historia se creará la tarea correspondiente en Jira (Refinamiento, Planning, etc.) con sus horas.",
                        wrap=True, xalign=0
                    )
                    self.left_frame.pack_start(lbl_form_sub, False, False, 2)

                    lbl_sel = Gtk.Label(xalign=0)
                    lbl_sel.set_markup(f"<span foreground='#2563eb'><b>Historia: {item_summary}</b></span>")
                    self.left_frame.pack_start(lbl_sel, False, False, 4)

                    # Fila Tiempo
                    row_time = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                    self.left_frame.pack_start(row_time, False, False, 2)
                    row_time.pack_start(Gtk.Label(label="Tiempo:"), False, False, 0)

                    self.combo_qty = Gtk.ComboBoxText()
                    for val in ["0.5", "1", "1.5", "2", "2.5", "3", "4", "8"]:
                        self.combo_qty.append_text(val)
                    self.combo_qty.set_active(1)
                    row_time.pack_start(self.combo_qty, False, False, 0)

                    self.combo_unit = Gtk.ComboBoxText()
                    self.combo_unit.append_text("Horas")
                    self.combo_unit.set_active(0)
                    row_time.pack_start(self.combo_unit, False, False, 0)

                    # Ceremonias
                    self.left_frame.pack_start(Gtk.Label(label="Ceremonia / Actividad:", xalign=0), False, False, 2)
                    self.combo_act = Gtk.ComboBoxText()
                    for act in ["Refinamiento", "Planning", "Retrospectiva", "Adicional"]:
                        self.combo_act.append_text(act)
                    self.combo_act.set_active(0)
                    self.left_frame.pack_start(self.combo_act, False, False, 0)

                    # Detalle
                    self.left_frame.pack_start(Gtk.Label(label="Detalle de la tarea a crear:", xalign=0), False, False, 2)
                    self.entry_detail = Gtk.Entry()
                    self.left_frame.pack_start(self.entry_detail, False, False, 4)

                    # Botón Crear tarea e insertar horas en Jira
                    btn_direct_jira = Gtk.Button(label="🚀 Crear tarea e insertar horas en Jira")
                    btn_direct_jira.get_style_context().add_class("btn-primary")
                    btn_direct_jira.connect("clicked", lambda w: self.register_direct_jira())
                    self.left_frame.pack_start(btn_direct_jira, False, False, 2)
                else:
                    lbl_form_title = Gtk.Label(label="<b>⚡ Registro para Tarea</b>", use_markup=True, xalign=0)
                    self.left_frame.pack_start(lbl_form_title, False, False, 0)

                    lbl_form_sub = Gtk.Label(label="Selecciona el tiempo a registrar en la tarea.", xalign=0)
                    self.left_frame.pack_start(lbl_form_sub, False, False, 2)

                    lbl_sel = Gtk.Label(xalign=0)
                    lbl_sel.set_markup(f"<span foreground='#2563eb'><b>Tarea: {item_summary}</b></span>")
                    self.left_frame.pack_start(lbl_sel, False, False, 4)

                    # Fila Tiempo
                    row_time = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                    self.left_frame.pack_start(row_time, False, False, 4)

                    row_time.pack_start(Gtk.Label(label="Cantidad:"), False, False, 0)
                    self.combo_qty = Gtk.ComboBoxText()
                    for val in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]:
                        self.combo_qty.append_text(val)
                    self.combo_qty.set_active(0)
                    row_time.pack_start(self.combo_qty, False, False, 0)

                    row_time.pack_start(Gtk.Label(label="Unidad:"), False, False, 0)
                    self.combo_unit = Gtk.ComboBoxText()
                    self.combo_unit.append_text("Horas")
                    self.combo_unit.append_text("Minutos")
                    self.combo_unit.set_active(0)
                    self.combo_unit.connect("changed", self.on_unit_change)
                    row_time.pack_start(self.combo_unit, False, False, 0)

                    btn_insert = Gtk.Button(label="⚡ INSERTAR HORAS")
                    btn_insert.get_style_context().add_class("btn-primary")
                    btn_insert.connect("clicked", lambda w: self.register_direct_jira())
                    self.left_frame.pack_start(btn_insert, False, False, 8)
        else:
            lbl_hist_title = Gtk.Label(label="<b>Resumen histórico</b>", use_markup=True, xalign=0)
            self.left_frame.pack_start(lbl_hist_title, False, False, 0)

            lbl_hist_sub = Gtk.Label(label=f"{format_date_es(self.selected_day)}\nVisualización de registros pasados.", xalign=0)
            self.left_frame.pack_start(lbl_hist_sub, False, False, 4)

        self.left_frame.show_all()

    def on_unit_change(self, combo):
        unit = combo.get_active_text()
        self.combo_qty.remove_all()
        if unit == "Minutos":
            for val in ["15", "30", "45", "60", "90", "120"]:
                self.combo_qty.append_text(val)
            self.combo_qty.set_active(1)
        else:
            for val in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]:
                self.combo_qty.append_text(val)
            self.combo_qty.set_active(0)

    def build_right_panel(self):
        # 1. Barra de Controles (Proyecto y Parent)
        self.controls_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.right_frame.pack_start(self.controls_bar, False, False, 2)

        self.controls_bar.pack_start(Gtk.Label(label="<b>📁 Proyecto:</b>", use_markup=True), False, False, 0)
        self.combo_project = Gtk.ComboBoxText()
        self.combo_project.append_text("Todos los proyectos")
        self.combo_project.set_active(0)
        self.combo_project.connect("changed", self.on_project_change)
        self.controls_bar.pack_start(self.combo_project, False, False, 0)

        self.controls_bar.pack_start(Gtk.Label(label="<b>📑 Parent:</b>", use_markup=True), False, False, 0)
        self.combo_parent = Gtk.ComboBoxText()
        self.combo_parent.append_text("Todos los parents")
        self.combo_parent.set_active(0)
        self.combo_parent.connect("changed", self.on_parent_change)
        self.controls_bar.pack_start(self.combo_parent, False, False, 0)

        # 2. SECCIÓN SUPERIOR: TAREAS
        self.upper_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.right_frame.pack_start(self.upper_frame, True, True, 2)

        upper_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.upper_frame.pack_start(upper_header_box, False, False, 0)

        self.lbl_tasks_header = Gtk.Label(label="<b>⚡ Tareas asignadas</b>", use_markup=True, xalign=0)
        upper_header_box.pack_start(self.lbl_tasks_header, True, True, 0)

        scroll_tasks = Gtk.ScrolledWindow()
        self.tree_tasks = Gtk.TreeView()
        self.setup_treeview(self.tree_tasks, ["Clave", "Tarea", "Estado", "Horas Jira"], [120, 680, 140, 100])
        self.tree_tasks.get_selection().connect("changed", self.on_task_select)
        self.tree_tasks.connect("row-activated", self.on_task_row_activated)
        scroll_tasks.add(self.tree_tasks)
        self.upper_frame.pack_start(scroll_tasks, True, True, 0)

        # 3. SECCIÓN INFERIOR: HISTORIAS
        self.lower_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.right_frame.pack_start(self.lower_frame, True, True, 2)

        lower_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.lower_frame.pack_start(lower_header_box, False, False, 0)

        self.lbl_stories_header = Gtk.Label(label="<b>📖 Historias de Usuario (Haz clic en una para ver sus tareas o registrar ceremonias)</b>", use_markup=True, xalign=0)
        lower_header_box.pack_start(self.lbl_stories_header, True, True, 0)

        scroll_stories = Gtk.ScrolledWindow()
        self.tree_stories = Gtk.TreeView()
        self.setup_treeview(self.tree_stories, ["Clave", "Historia", "Estado", "Horas Jira"], [120, 680, 140, 100])
        self.tree_stories.get_selection().connect("changed", self.on_story_select)
        self.tree_stories.connect("row-activated", self.on_story_row_activated)
        scroll_stories.add(self.tree_stories)
        self.lower_frame.pack_start(scroll_stories, True, True, 0)

    def setup_treeview(self, treeview, headers, widths):
        model = Gtk.ListStore(str, str, str, str, object)
        treeview.set_model(model)
        for i, (h, w) in enumerate(zip(headers, widths)):
            renderer = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn(h, renderer, text=i)
            col.set_min_width(w)
            if i == 1:
                col.set_expand(True)
            treeview.append_column(col)

    def on_task_select(self, selection):
        model, treeiter = selection.get_selected()
        if treeiter:
            self.active_selection_type = "task"
            self.build_left_panel()

    def on_story_select(self, selection):
        model, treeiter = selection.get_selected()
        if treeiter:
            key = model[treeiter][0]
            self.selected_story_key = key
            self.active_selection_type = "story"
            self.build_left_panel()
            self.render_tasks_table()

    def on_task_row_activated(self, treeview, path, column):
        if self.selected_day == date.today().isoformat():
            self.active_selection_type = "task"
            self.insert_local_work()

    def on_story_row_activated(self, treeview, path, column):
        if self.selected_day == date.today().isoformat():
            self.active_selection_type = "story"
            self.build_left_panel()

    def clear_story_selection(self):
        self.selected_story_key = None
        self.tree_stories.get_selection().unselect_all()
        self.active_selection_type = "task"
        self.build_left_panel()
        self.render_tasks_table()

    def update_project_dropdown(self):
        projects_ordered = []
        for it in self.issues:
            p = it.get("project")
            if p and p != "-" and p not in projects_ordered:
                projects_ordered.append(p)

        self.combo_project.remove_all()
        self.combo_project.append_text("Todos los proyectos")
        for p in projects_ordered:
            self.combo_project.append_text(p)

        if projects_ordered and (self.selected_project == "Todos los proyectos" or self.selected_project not in projects_ordered):
            self.selected_project = projects_ordered[0]
            self.combo_project.set_active(1)
        else:
            self.combo_project.set_active(0)

        self.update_parent_dropdown()

    def update_parent_dropdown(self):
        parents_ordered = []
        for it in self.issues:
            if self.selected_project != "Todos los proyectos" and it.get("project") != self.selected_project:
                continue
            parent_name = it.get("parent")
            if parent_name and parent_name != "-" and parent_name not in parents_ordered:
                parents_ordered.append(parent_name)

        self.combo_parent.remove_all()
        self.combo_parent.append_text("Todos los parents")
        for p in parents_ordered:
            self.combo_parent.append_text(p)

        if parents_ordered and (self.selected_parent == "Todos los parents" or self.selected_parent not in parents_ordered):
            self.selected_parent = parents_ordered[0]
            self.combo_parent.set_active(1)
        else:
            self.selected_parent = "Todos los parents"
            self.combo_parent.set_active(0)

    def on_project_change(self, combo):
        self.selected_project = combo.get_active_text() or "Todos los proyectos"
        self.selected_parent = "Todos los parents"
        self.selected_story_key = None
        self.tree_tasks.get_selection().unselect_all()
        self.tree_stories.get_selection().unselect_all()
        self.update_parent_dropdown()
        self.render_table()
        self.build_left_panel()

    def on_parent_change(self, combo):
        self.selected_parent = combo.get_active_text() or "Todos los parents"
        self.selected_story_key = None
        self.tree_tasks.get_selection().unselect_all()
        self.tree_stories.get_selection().unselect_all()
        self.render_table()
        self.build_left_panel()

    def on_search(self, entry):
        self.search_filter = entry.get_text()
        self.tree_tasks.get_selection().unselect_all()
        self.tree_stories.get_selection().unselect_all()
        self.render_table()
        self.build_left_panel()

    def get_selected_issue(self):
        if self.active_selection_type == "story":
            sel = self.tree_stories.get_selection()
            model, treeiter = sel.get_selected()
            if treeiter:
                return model[treeiter][4]
        else:
            sel = self.tree_tasks.get_selection()
            model, treeiter = sel.get_selected()
            if treeiter:
                return model[treeiter][4]
        return None

    def update_totals_ui(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        jira_total = sum(float(item.get("hours", 0)) for item in jira_worklogs)
        local_total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total = jira_total + local_total
        min_hours = 6.5
        max_hours = 10.5

        self.lbl_day_title.set_markup(f"<b><big>Resumen de {format_date_es(self.selected_day)}</big></b>")
        self.lbl_total_hours.set_text(format_hours(total))
        self.lbl_sub_hours.set_text(f"Jira: {format_hours(jira_total)}  ·  Preparadas: {format_hours(local_total)}")

        if total < min_hours:
            diff_min = min_hours - total
            self.lbl_status.set_markup(f"<span foreground='#dc2626'><b>Faltan mínimo {format_hours(diff_min)}</b></span>")
        elif total <= max_hours:
            self.lbl_status.set_markup("<span foreground='#16a34a'><b>✓ Jornada completa</b></span>")
        else:
            diff_over = total - max_hours
            self.lbl_status.set_markup(f"<span foreground='#dc2626'><b>⚠ Se sobrepasó por {format_hours(diff_over)}</b></span>")

        is_today = (self.selected_day == date.today().isoformat())
        self.btn_next.set_sensitive(not is_today)

    def render_table(self):
        is_today = (self.selected_day == date.today().isoformat())
        if is_today:
            self.lower_frame.show()
            self.render_tasks_table()
            self.render_stories_table()
        else:
            self.lower_frame.hide()

            model = self.tree_tasks.get_model()
            model.clear()
            curr_state = day_state(self.state, self.selected_day)
            jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
            historical = [*jira_worklogs, *curr_state.get("worklogs", [])]

            self.lbl_tasks_header.set_markup(f"<b>Trabajo realizado ({len(historical)} registros del {format_date_es(self.selected_day)})</b>")
            query = self.search_filter.lower().strip()

            for item in historical:
                text_to_search = f"{item.get('key', '')} {item.get('story', '')} {item.get('summary', '')}".lower()
                if query and query not in text_to_search:
                    continue
                model.append([
                    item.get("key", "—"),
                    f"{item.get('story', '—')} | {item.get('summary', '')}",
                    item.get("activity", "—"),
                    format_hours(item.get("hours", 0)),
                    item
                ])

    def render_tasks_table(self):
        model = self.tree_tasks.get_model()
        model.clear()
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
            self.lbl_tasks_header.set_markup(f"<b>⚡ Tareas asociadas a {self.selected_story_key} ({len(filtered_tasks)} encontradas)</b>")
        else:
            self.lbl_tasks_header.set_markup(f"<b>⚡ Todas mis tareas asignadas ({len(filtered_tasks)} disponibles)</b>")

        for task in filtered_tasks:
            model.append([task["key"], task["summary"], task["status"], task["hours"], task])

    def render_stories_table(self):
        model = self.tree_stories.get_model()
        model.clear()
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

        self.lbl_stories_header.set_markup(f"<b>📖 Historias de Usuario ({len(filtered_stories)} disponibles)</b>")

        for story in filtered_stories:
            treeiter = model.append([story["key"], story["summary"], story["status"], story["hours"], story])
            if self.selected_story_key and story["key"] == self.selected_story_key:
                self.tree_stories.get_selection().select_iter(treeiter)

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

                GLib.idle_add(update_ui)
            except Exception as e:
                err_msg = str(e)
                GLib.idle_add(lambda: self.set_loading(False, f"Error: {err_msg}"))

        threading.Thread(target=task, daemon=True).start()

    def set_loading(self, loading, text=""):
        self.lbl_loading.set_text(text if loading else "")

    def insert_local_work(self):
        issue = self.get_selected_issue()
        if not issue:
            self.show_dialog("Selecciona una tarea o historia", "Selecciona una tarea o historia de la lista antes de insertar.")
            return

        unit = self.combo_unit.get_active_text() if hasattr(self, 'combo_unit') else "Horas"
        try:
            amount = float(self.combo_qty.get_active_text())
        except Exception:
            amount = 1.0

        hours = amount / 60.0 if unit == "Minutos" else amount
        curr_state = day_state(self.state, self.selected_day)
        curr_state["selected"] = amount
        curr_state["unit"] = unit

        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        total = sum(float(item.get("hours", 0)) for item in curr_state.get("worklogs", []))
        total += sum(float(item.get("hours", 0)) for item in jira_worklogs)

        if total + hours > 10.5:
            self.show_dialog("Máximo diario", "El registro superaría el máximo diario de 10 h 30 min.")
            return

        is_story = (self.active_selection_type == 'story')
        activity = self.combo_act.get_active_text() if (is_story and hasattr(self, 'combo_act')) else "Trabajo en tarea"
        detail = self.entry_detail.get_text().strip() if (is_story and hasattr(self, 'entry_detail')) else ""
        final_activity = detail if activity == "Adicional" and detail else activity

        curr_state["worklogs"].append({
            "key": issue["key"],
            "summary": f"{activity}: {detail}" if (is_story and detail) else issue["summary"],
            "hours": hours,
            "activity": final_activity,
            "created": datetime.now().isoformat(timespec="seconds"),
        })
        save_state(self.state)
        self.update_totals_ui()
        if is_story and hasattr(self, 'entry_detail'):
            self.entry_detail.set_text("")
        self.show_dialog("Registro preparado", f"Se añadieron {format_hours(hours)} a {issue['key']} en la lista preparada.")

    def register_direct_jira(self):
        issue = self.get_selected_issue()
        if not issue:
            self.show_dialog("Selecciona un elemento", "Selecciona una tarea o historia de la lista antes de registrar.")
            return

        unit = self.combo_unit.get_active_text() if hasattr(self, 'combo_unit') else "Horas"
        try:
            amount = float(self.combo_qty.get_active_text())
        except Exception:
            amount = 1.0

        hours = amount / 60.0 if unit == "Minutos" else amount
        is_story = (issue.get("type") in ("Historia de usuario", "Story", "Historia"))
        activity = self.combo_act.get_active_text() if (is_story and hasattr(self, 'combo_act')) else "Trabajo en tarea"
        detail = self.entry_detail.get_text().strip() if (is_story and hasattr(self, 'entry_detail')) else ""
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

        if not self.ask_yes_no("Confirmar registro en Jira", prompt_text):
            return

        self.set_loading(True, "Creando tarea y registrando en Jira…" if is_story else "Registrando en Jira…")

        def task():
            try:
                target_key = issue["key"]
                if is_story:
                    new_task_key, _ = create_task_for_story(self.config_data, issue, activity, detail)
                    target_key = new_task_key

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
                    if self.ask_yes_no("Registro exitoso", msg):
                        webbrowser.open(url)

                GLib.idle_add(on_success)
            except Exception as err:
                err_msg = str(err)
                GLib.idle_add(lambda: self.show_dialog("Error al registrar en Jira", err_msg))

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
        self.build_left_panel()
        self.update_totals_ui()
        self.render_table()

        if self.selected_day not in self.jira_worklogs_cache:
            self.set_loading(True, f"Cargando registros del {self.selected_day}…")
            def task():
                try:
                    logs = get_jira_worklogs(self.config_data, self.selected_day)
                    self.jira_worklogs_cache[self.selected_day] = logs
                    def update():
                        self.set_loading(False)
                        self.update_totals_ui()
                        self.render_table()
                    GLib.idle_add(update)
                except Exception:
                    GLib.idle_add(lambda: self.set_loading(False))
            threading.Thread(target=task, daemon=True).start()

    def show_day_detail(self):
        curr_state = day_state(self.state, self.selected_day)
        jira_worklogs = self.jira_worklogs_cache.get(self.selected_day, [])
        all_rows = [*jira_worklogs, *curr_state.get("worklogs", [])]

        dialog = Gtk.Dialog(title=f"Detalle · {format_date_es(self.selected_day)}", parent=self, flags=0)
        dialog.set_default_size(1050, 500)
        dialog_box = dialog.get_content_area()
        dialog_box.set_spacing(10)
        dialog_box.set_margin_start(12)
        dialog_box.set_margin_end(12)
        dialog_box.set_margin_top(12)

        lbl = Gtk.Label(xalign=0)
        lbl.set_markup(f"<b><big>Registros del {format_date_es(self.selected_day)}</big></b>")
        dialog_box.pack_start(lbl, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        tree = Gtk.TreeView()
        model = Gtk.ListStore(str, str, str, str, object)
        tree.set_model(model)

        for i, (h, w) in enumerate([("Clave", 120), ("Historia / Parent Asociada", 360), ("Tarea", 440), ("Horas", 90)]):
            renderer = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn(h, renderer, text=i)
            col.set_min_width(w)
            if i in (1, 2):
                col.set_expand(True)
            tree.append_column(col)

        for it in all_rows:
            model.append([
                it.get("key", "—"),
                it.get("story", "—"),
                it.get("summary", ""),
                format_hours(it.get("hours", 0)),
                it
            ])

        scroll.add(tree)
        dialog_box.pack_start(scroll, True, True, 0)

        # Botones de acción del diálogo
        action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        dialog_box.pack_start(action_box, False, False, 6)

        def print_pdf_action():
            if not all_rows:
                self.show_dialog("Sin registros", "No hay registros disponibles para generar el PDF.")
                return
            subprocess.Popen([sys.executable, "/home/user/monoliths-llm/registro-diario-1bit.py", "--generate-pdf-bg", self.selected_day],
                             start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            dialog.destroy()
            self.destroy()
            os._exit(0)

        btn_pdf = Gtk.Button(label="📄 Imprimir PDF (1 pág/reg)")
        btn_pdf.get_style_context().add_class("btn-primary")
        btn_pdf.connect("clicked", lambda w: print_pdf_action())
        action_box.pack_start(btn_pdf, False, False, 0)

        def open_in_jira():
            sel = tree.get_selection()
            m, it_sel = sel.get_selected()
            if it_sel:
                k = m[it_sel][0]
                if k and k != "—":
                    domain = self.config_data.get("JIRA_DOMAIN", "").rstrip("/")
                    webbrowser.open(f"{domain}/browse/{k}")

        btn_open = Gtk.Button(label="Abrir seleccionado en Jira")
        btn_open.get_style_context().add_class("btn-secondary")
        btn_open.connect("clicked", lambda w: open_in_jira())
        action_box.pack_start(btn_open, False, False, 0)

        btn_close = Gtk.Button(label="Cerrar")
        btn_close.get_style_context().add_class("btn-secondary")
        btn_close.connect("clicked", lambda w: dialog.destroy())
        action_box.pack_end(btn_close, False, False, 0)

        dialog.show_all()

    def show_dialog(self, title, message):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text=title,
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

    def ask_yes_no(self, title, message):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text=title,
        )
        dialog.format_secondary_text(message)
        response = dialog.run()
        dialog.destroy()
        return response == Gtk.ResponseType.YES


def main():
    config = read_config()
    app = RegistroDiarioGtkApp(config)
    app.show_all()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
