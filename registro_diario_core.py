#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
registro_diario_core.py - Funciones centrales compartidas de Jira y persistencia
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

CONFIG = os.path.expanduser("~/.justificar/jira_config")
CSV = os.path.expanduser("~/.justificar/justificar.csv")
STATE_FILE = os.path.expanduser("~/.justificar/registro-diario-yad.json")

_CACHED_ISSUES = None
_CACHED_WORKLOGS = {}

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
        return
    except RuntimeError as error:
        if "401" not in str(error):
            raise
    tenant_url = config["JIRA_DOMAIN"].rstrip("/") + "/_edge/tenant_info"
    try:
        with urllib.request.urlopen(tenant_url, timeout=15) as response:
            cloud_id = json.loads(response.read().decode()).get("cloudId")
    except Exception as error:
        raise RuntimeError("No se pudo obtener cloudId.") from error
    if not cloud_id:
        raise RuntimeError("Jira no devolvió un cloudId.")
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
            "hours": f"{seconds / 3600:g}h",
            "type": itype,
            "linked_stories": linked_stories,
            "linked_tasks": linked_tasks,
        })
    return rows

def get_cached_issues(config):
    global _CACHED_ISSUES
    if _CACHED_ISSUES is None:
        _CACHED_ISSUES = get_issues(config)
    return _CACHED_ISSUES

def refresh_cache(config):
    global _CACHED_ISSUES, _CACHED_WORKLOGS
    _CACHED_ISSUES = get_issues(config)
    _CACHED_WORKLOGS.clear()

def clear_worklogs_cache(target_day=None):
    global _CACHED_WORKLOGS
    if target_day:
        _CACHED_WORKLOGS.pop(target_day, None)
    else:
        _CACHED_WORKLOGS.clear()

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

def get_cached_worklogs(config, selected_day):
    global _CACHED_WORKLOGS
    if selected_day not in _CACHED_WORKLOGS:
        _CACHED_WORKLOGS[selected_day] = get_jira_worklogs(config, selected_day)
    return _CACHED_WORKLOGS[selected_day]

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
