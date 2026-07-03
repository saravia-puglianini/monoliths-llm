#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error
import base64

CONFIG_PATH = os.path.expanduser("~/.justificar/jira_config")

def load_config():
    if not os.path.exists(CONFIG_PATH):
        print("ERROR: No se encontró el archivo de configuración en " + CONFIG_PATH, file=sys.stderr)
        sys.exit(1)
    
    config = {}
    with open(CONFIG_PATH, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                val = val.strip().strip('"').strip("'")
                config[key.strip()] = val
    
    required = ["JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_DOMAIN"]
    for req in required:
        if req not in config or not config[req]:
            print(f"ERROR: Falta la variable {req} en {CONFIG_PATH}", file=sys.stderr)
            sys.exit(1)
            
    return config

def make_request(config, path, method="GET", payload=None):
    url = config["JIRA_DOMAIN"].rstrip("/") + path
    auth_str = f"{config['JIRA_EMAIL']}:{config['JIRA_API_TOKEN']}"
    auth_b64 = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")
    
    headers = {
        "Authorization": f"Basic {auth_b64}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    req_data = None
    if payload is not None:
        req_data = json.dumps(payload).encode("utf-8")
        
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"Jira API Error ({e.code}): {err_body}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error al conectar con Jira: {e}", file=sys.stderr)
        sys.exit(1)

def get_issues():
    config = load_config()
    jql = 'assignee = currentUser() AND statusCategory != Done AND issuetype in (Task, Tarea, "Sub-task", Subtarea) ORDER BY updated DESC'
    payload = {
        "jql": jql,
        "maxResults": 50,
        "fields": ["key", "summary", "project", "parent", "status", "issuelinks"]
    }
    
    res = make_request(config, "/rest/api/3/search/jql", method="POST", payload=payload)
    issues = res.get("issues", [])
    
    # Print in YAD format: KEY|PROJECT_KEY|PARENT_SUMMARY_TRUNCATED|PROJECT_NAME|PARENT_KEY_WITH_STATUS|PARENT_SUMMARY|TASK_SUMMARY_WITH_STATUS
    for issue in issues:
        key = issue["key"]
        fields = issue.get("fields", {})
        summary = fields.get("summary", "")
        task_status = fields.get("status", {}).get("name", "N/A")
        
        project = fields.get("project", {})
        project_key = project.get("key", "N/A")
        project_name = project.get("name", "N/A")
        
        parent_key = "N/A"
        parent_summary = "N/A"
        parent_status = "N/A"
        
        # Check if parent is a Story
        parent_obj = fields.get("parent", {})
        if parent_obj:
            p_fields = parent_obj.get("fields", {})
            p_type = p_fields.get("issuetype", {}).get("name", "")
            p_summary = p_fields.get("summary", "")
            if p_type in ["Story", "Historia", "Historia de usuario"] or p_summary.startswith("HU"):
                parent_key = parent_obj.get("key", "N/A")
                parent_summary = p_summary
                parent_status = p_fields.get("status", {}).get("name", "N/A")
        
        # Fallback to issuelinks to find the Story (e.g. HU20, HU30, etc.)
        if parent_key == "N/A":
            for link in fields.get("issuelinks", []):
                linked_issue = link.get("inwardIssue") or link.get("outwardIssue")
                if linked_issue:
                    li_fields = linked_issue.get("fields", {})
                    li_type = li_fields.get("issuetype", {}).get("name", "")
                    li_summary = li_fields.get("summary", "")
                    if li_type in ["Story", "Historia", "Historia de usuario"] or li_summary.startswith("HU"):
                        parent_key = linked_issue.get("key", "N/A")
                        parent_summary = li_summary
                        parent_status = li_fields.get("status", {}).get("name", "N/A")
                        break
                        
        if parent_key != "N/A":
            parent_key_display = f"{parent_key} ({parent_status})"
        else:
            parent_key_display = "N/A"
            
        task_summary_display = f"{summary} ({task_status})"
        
        if parent_summary != "N/A" and len(parent_summary) > 10:
            parent_summary_truncated = parent_summary[:10] + "..."
        else:
            parent_summary_truncated = parent_summary
            
        # Clean pipes and newlines
        task_summary_display = task_summary_display.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        parent_summary_truncated = parent_summary_truncated.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        project_name = project_name.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        project_key = project_key.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        parent_key_display = parent_key_display.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        parent_summary = parent_summary.replace("|", " ").replace("\n", " ").replace("\r", " ").strip()
        
        print(f"{key}|{project_name}|{parent_key_display}|{parent_summary}|{task_summary_display}")

def log_work(issue_key, hours, comment):
    config = load_config()
    # Jira accepts timeSpent like "1h", "2h", or in seconds. We pass it in hours/minutes.
    # Convert hours string to timeSpent (e.g. "1h" or "2h")
    try:
        hours_val = float(hours)
        if hours_val.is_integer():
            time_spent = f"{int(hours_val)}h"
        else:
            time_spent = f"{int(hours_val * 60)}m"
    except ValueError:
        time_spent = f"{hours}h" # fallback if not number

    payload = {
        "comment": comment,
        "timeSpent": time_spent
    }
    
    path = f"/rest/api/2/issue/{issue_key}/worklog"
    res = make_request(config, path, method="POST", payload=payload)
    print(f"SUCCESS: Horas registradas en {issue_key}")

def transition_issue(issue_key, target_status):
    # target_status can be: 'in_progress', 'detenido', 'hecho'
    config = load_config()
    
    # Get available transitions
    path = f"/rest/api/3/issue/{issue_key}/transitions"
    try:
        res = make_request(config, path, method="GET")
    except Exception as e:
        print(f"Error al obtener transiciones para {issue_key}: {e}", file=sys.stderr)
        return False
        
    transitions = res.get("transitions", [])
    
    # Find matching transition
    transition_id = None
    target_status = target_status.lower()
    
    if target_status == "in_progress":
        # Look for "en progreso", "in progress", "en curso"
        for t in transitions:
            name = t["name"].lower()
            to_name = t["to"]["name"].lower()
            if "progreso" in name or "progress" in name or "curso" in name or "progreso" in to_name or "progress" in to_name or "curso" in to_name:
                transition_id = t["id"]
                break
    elif target_status == "detenido":
        # Look for "detenido", "pausa", "stop", "por hacer", "to do", "backlog"
        for t in transitions:
            name = t["name"].lower()
            to_name = t["to"]["name"].lower()
            if "detenido" in name or "pausa" in name or "stop" in name or "detenido" in to_name or "pausa" in to_name or "stop" in to_name:
                transition_id = t["id"]
                break
        if not transition_id:
            # Fallback to "por hacer", "to do", "backlog"
            for t in transitions:
                name = t["name"].lower()
                if "hacer" in name or "todo" in name or "backlog" in name:
                    transition_id = t["id"]
                    break
    elif target_status == "hecho":
        # Look for "hecho", "done", "completado", "finalizado"
        for t in transitions:
            name = t["name"].lower()
            to_name = t["to"]["name"].lower()
            if "hecho" in name or "done" in name or "completado" in name or "finalizado" in name or "hecho" in to_name or "done" in to_name or "completado" in to_name or "finalizado" in to_name:
                transition_id = t["id"]
                break
                
    if transition_id:
        # Perform transition
        payload = {
            "transition": {
                "id": str(transition_id)
            }
        }
        try:
            make_request(config, path, method="POST", payload=payload)
            print(f"SUCCESS: {issue_key} transicionado a {target_status} (ID {transition_id})")
            return True
        except Exception as e:
            print(f"Error al transicionar {issue_key} a {target_status}: {e}", file=sys.stderr)
            return False
    else:
        print(f"WARNING: No se encontró transición adecuada para {target_status} en {issue_key}", file=sys.stderr)
        return False

def get_parent_key(issue_key):
    config = load_config()
    path = f"/rest/api/3/issue/{issue_key}?fields=parent,issuelinks"
    try:
        res = make_request(config, path, method="GET")
        fields = res.get("fields", {})
        
        parent_obj = fields.get("parent", {})
        if parent_obj:
            p_fields = parent_obj.get("fields", {})
            p_type = p_fields.get("issuetype", {}).get("name", "")
            p_summary = p_fields.get("summary", "")
            if p_type in ["Story", "Historia", "Historia de usuario"] or p_summary.startswith("HU"):
                return parent_obj.get("key", "N/A")
                
        for link in fields.get("issuelinks", []):
            linked_issue = link.get("inwardIssue") or link.get("outwardIssue")
            if linked_issue:
                li_fields = linked_issue.get("fields", {})
                li_type = li_fields.get("issuetype", {}).get("name", "")
                li_summary = li_fields.get("summary", "")
                if li_type in ["Story", "Historia", "Historia de usuario"] or li_summary.startswith("HU"):
                    return linked_issue.get("key", "N/A")
                    
        return "N/A"
    except Exception:
        return "N/A"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: jira_helper.py [get-issues | log-work | transition | get-parent]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    if cmd == "get-issues":
        get_issues()
    elif cmd == "log-work":
        if len(sys.argv) < 5:
            print("Uso: jira_helper.py log-work <key> <hours> <comment>")
            sys.exit(1)
        key = sys.argv[2]
        hours = sys.argv[3]
        comment = sys.argv[4]
        log_work(key, hours, comment)
    elif cmd == "transition":
        if len(sys.argv) < 4:
            print("Uso: jira_helper.py transition <key> <status>")
            sys.exit(1)
        key = sys.argv[2]
        status = sys.argv[3]
        transition_issue(key, status)
    elif cmd == "get-parent":
        if len(sys.argv) < 3:
            print("Uso: jira_helper.py get-parent <key>")
            sys.exit(1)
        print(get_parent_key(sys.argv[2]))
    else:
        print(f"Comando desconocido: {cmd}")
        sys.exit(1)
