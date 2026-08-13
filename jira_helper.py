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
    jql = 'assignee = currentUser() AND (statusCategory != Done OR status = "En medición") AND issuetype in (Task, Tarea, "Sub-task", Subtarea, Correctivos, "Error en producción", Incidencias) ORDER BY updated DESC'
    payload = {
        "jql": jql,
        "maxResults": 50,
        "fields": ["key", "summary", "project", "parent", "status", "issuelinks", "timespent", "aggregatetimespent"]
    }
    
    res = make_request(config, "/rest/api/3/search/jql", method="POST", payload=payload)
    issues = res.get("issues", [])
    
    # Print in YAD format: KEY|PROJECT_KEY|PARENT_SUMMARY_TRUNCATED|PROJECT_NAME|PARENT_KEY_WITH_STATUS|PARENT_SUMMARY|TASK_SUMMARY_WITH_STATUS|HOURS_SPENT
    for issue in issues:
        key = issue["key"]
        fields = issue.get("fields", {})
        summary = fields.get("summary", "")
        task_status = fields.get("status", {}).get("name", "N/A")
        
        # Calculate time spent in hours
        ts_sec = fields.get("timespent") or fields.get("aggregatetimespent") or 0
        ts_hours = ts_sec / 3600.0
        if ts_hours == 0:
            hours_spent = "0 hrs"
        elif ts_hours.is_integer():
            hours_spent = f"{int(ts_hours)} hr" if int(ts_hours) == 1 else f"{int(ts_hours)} hrs"
        else:
            hours_spent = f"{ts_hours:.1f} hrs"
        
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
        hours_spent = hours_spent.replace("|", " ").strip()
        
        print(f"{key}|{project_name}|{parent_key_display}|{parent_summary}|{task_summary_display}|{hours_spent}")

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
    worklog_id = res.get("id")
    domain = config["JIRA_DOMAIN"].rstrip("/")
    url = f"{domain}/browse/{issue_key}?focusedWorklogId={worklog_id}&page=com.atlassian.jira.plugin.system.issuetabpanels:worklog-tabpanel#worklog-{worklog_id}"
    print(url)

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

def open_report(target_date=None):
    import subprocess
    csv_path = os.path.expanduser("~/.justificar/justificar.csv")
    if not os.path.exists(csv_path):
        subprocess.run(["yad", "--title=Error", "--text=No se encontró el archivo de log.", "--button=OK:0", "--center", "--always-on-top"])
        return
        
    # Leer todas las entradas
    entries = []
    with open(csv_path, "r") as f:
        for line in f:
            parts = line.strip().split(";")
            if len(parts) >= 4:
                fecha = parts[0]
                hora = parts[1]
                proyecto = parts[2]
                descripcion = parts[3]
                link = parts[4] if len(parts) > 4 else ""
                entries.append({
                    "fecha": fecha,
                    "hora": hora,
                    "proyecto": proyecto,
                    "descripcion": descripcion,
                    "link": link
                })
                
    if not entries:
        subprocess.run(["yad", "--title=Error", "--text=El archivo de log está vacío.", "--button=OK:0", "--center", "--always-on-top"])
        return

    # Si no se pasó fecha, preguntar usando YAD
    if not target_date:
        # Agrupar por fecha para contar horas y listar
        from collections import defaultdict
        date_counts = defaultdict(int)
        for entry in entries:
            date_counts[entry["fecha"]] += 1
            
        # Obtener las últimas 7 fechas únicas en orden descendente
        unique_dates = sorted(list(date_counts.keys()), reverse=True)[:7]
        
        if not unique_dates:
            subprocess.run(["yad", "--title=Error", "--text=No hay fechas registradas.", "--button=OK:0", "--center", "--always-on-top"])
            return
            
        # Determinar la fecha pre-seleccionada por defecto
        # Si hoy tiene 8 horas, pre-seleccionar hoy. Si no, pre-seleccionar la última fecha que tenga 8 horas (o la última fecha registrada)
        import datetime
        today_str = datetime.date.today().strftime("%Y-%m-%d")
        
        default_date = unique_dates[0] # por defecto la más reciente
        for d in unique_dates:
            if d == today_str and date_counts[d] == 8:
                default_date = d
                break
            elif date_counts[d] == 8:
                default_date = d
                break

        # Construir argumentos para YAD
        yad_args = ["yad", "--list", "--title=Seleccionar Fecha de Reporte", 
                    "--text=Seleccione el día para abrir los reportes en Chrome:", 
                    "--column=Fecha", "--column=Horas Registradas", 
                    "--height=250", "--width=350", "--center", "--always-on-top",
                    "--button=Cancelar:1", "--button=Abrir Reporte:0"]
        
        for d in unique_dates:
            yad_args.extend([d, f"{date_counts[d]}/8 horas"])
            
        try:
            res = subprocess.run(yad_args, capture_output=True, text=True)
            if res.returncode != 0 or not res.stdout:
                return # Cancelado
            # YAD devuelve "fecha|horas|"
            target_date = res.stdout.split("|")[0].strip()
        except Exception as e:
            subprocess.run(["yad", "--title=Error", "--text=Error al ejecutar YAD.", "--button=OK:0", "--center", "--always-on-top"])
            return

    # Obtener los enlaces para la fecha seleccionada
    config = {}
    try:
        config = load_config()
    except SystemExit:
        pass
    jira_domain = config.get("JIRA_DOMAIN", "https://mipandero.atlassian.net").rstrip("/")

    links = []
    import re
    jira_key_pattern = re.compile(r'^[A-Za-z0-9]+-[0-9]+$')
    
    for entry in entries:
        if entry["fecha"] == target_date:
            link = entry["link"]
            proyecto = entry["proyecto"]
            if link and link.startswith("http"):
                if "focusedWorklogId=" in link and "page=" not in link:
                    import urllib.parse
                    parsed = urllib.parse.urlparse(link)
                    params = urllib.parse.parse_qs(parsed.query)
                    wl_ids = params.get("focusedWorklogId", [])
                    if wl_ids:
                        wl_id = wl_ids[0]
                        link = f"{link}&page=com.atlassian.jira.plugin.system.issuetabpanels:worklog-tabpanel#worklog-{wl_id}"
                links.append(link)
            elif jira_key_pattern.match(proyecto):
                links.append(f"{jira_domain}/browse/{proyecto}")
                
    if not links:
        subprocess.run(["yad", "--title=Información", "--text=No se encontraron enlaces de Jira para abrir para la fecha seleccionada.", "--button=OK:0", "--center", "--always-on-top"])
        return

    # Eliminar duplicados manteniendo el orden
    unique_links = []
    for l in links:
        if l not in unique_links:
            unique_links.append(l)

    # Abrir en google-chrome-stable
    chrome_bin = "/usr/bin/google-chrome-stable"
    if not os.path.exists(chrome_bin):
        chrome_bin = "google-chrome-stable"
        
    try:
        subprocess.Popen([chrome_bin] + unique_links, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        for l in unique_links:
            subprocess.Popen(["xdg-open", l], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def sync_worklogs(target_date):
    config = load_config()
    
    # 1. Get myself to obtain accountId
    try:
        myself = make_request(config, "/rest/api/3/myself")
        account_id = myself.get("accountId")
    except Exception as e:
        print(f"Error checking user profile: {e}", file=sys.stderr)
        return
        
    if not account_id:
        print("ERROR: Could not retrieve accountId", file=sys.stderr)
        return
        
    # 2. Search for issues with worklogs by current user on target_date
    jql = f'worklogAuthor = currentUser() AND worklogDate = "{target_date}"'
    payload = {
        "jql": jql,
        "maxResults": 100,
        "fields": ["key"]
    }
    
    try:
        res = make_request(config, "/rest/api/3/search/jql", method="POST", payload=payload)
    except Exception as e:
        print(f"Error searching issues: {e}", file=sys.stderr)
        return
        
    issues = res.get("issues", [])
    if not issues:
        return
        
    csv_path = os.path.expanduser("~/.justificar/justificar.csv")
    existing_lines = []
    if os.path.exists(csv_path):
        with open(csv_path, "r") as f:
            existing_lines = [line.strip() for line in f if line.strip()]
            
    # Parse existing CSV to know which hours are already used for the target_date
    used_hours = set()
    for line in existing_lines:
        parts = line.split(";")
        if len(parts) >= 2 and parts[0] == target_date:
            used_hours.add(parts[1])
            
    # Extract existing worklog IDs from CSV to avoid duplicates
    import re
    existing_worklog_ids = set()
    for line in existing_lines:
        parts = line.split(";")
        if len(parts) >= 5:
            url = parts[4]
            match = re.search(r"focusedWorklogId=(\d+)", url)
            if match:
                existing_worklog_ids.add(match.group(1))

    # Standard billing hours
    horas_laborales_strs = ["9am", "10am", "11am", "12pm", "2pm", "3pm", "4pm", "5pm"]
    
    new_entries = []
    
    # 3. Fetch all worklogs for these issues
    for issue in issues:
        issue_key = issue["key"]
        path = f"/rest/api/2/issue/{issue_key}/worklog"
        try:
            wl_res = make_request(config, path, method="GET")
        except Exception as e:
            print(f"Error getting worklogs for {issue_key}: {e}", file=sys.stderr)
            continue
            
        worklogs = wl_res.get("worklogs", [])
        for wl in worklogs:
            wl_id = wl.get("id")
            wl_author = wl.get("author", {})
            wl_author_id = wl_author.get("accountId")
            started = wl.get("started", "")
            
            # Check if author matches current user, and starts on the target date
            if wl_author_id == account_id and started.startswith(target_date):
                if wl_id in existing_worklog_ids:
                    continue
                    
                time_spent_seconds = wl.get("timeSpentSeconds", 0)
                hours_count = max(1, int(round(time_spent_seconds / 3600.0)))
                comment = wl.get("comment", "")
                
                # Construct worklog URL
                domain = config["JIRA_DOMAIN"].rstrip("/")
                wl_url = f"{domain}/browse/{issue_key}?focusedWorklogId={wl_id}&page=com.atlassian.jira.plugin.system.issuetabpanels:worklog-tabpanel#worklog-{wl_id}"
                
                for _ in range(hours_count):
                    assigned_hour = None
                    for h_str in horas_laborales_strs:
                        if h_str not in used_hours:
                            assigned_hour = h_str
                            used_hours.add(h_str)
                            break
                            
                    if not assigned_hour:
                        # Fallback for extra/overtime hours
                        idx = len(used_hours) + 9
                        if idx < 12:
                            h_fallback = f"{idx}am"
                        elif idx == 12:
                            h_fallback = "12pm"
                        else:
                            h_fallback = f"{idx-12}pm"
                        assigned_hour = h_fallback
                        used_hours.add(h_fallback)
                        
                    new_entries.append((target_date, assigned_hour, issue_key, comment, wl_url))
                    
    if new_entries:
        with open(csv_path, "a") as f:
            for entry in new_entries:
                f.write(";".join(entry) + "\n")
        print(f"Synced {len(new_entries)} worklog hour(s) from Jira to local CSV.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: jira_helper.py [get-issues | log-work | transition | get-parent | open-report | sync]")
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
    elif cmd == "open-report":
        target_date = sys.argv[2] if len(sys.argv) > 2 else None
        open_report(target_date)
    elif cmd == "sync":
        if len(sys.argv) < 3:
            print("Uso: jira_helper.py sync <date>")
            sys.exit(1)
        sync_worklogs(sys.argv[2])
    else:
        print(f"Comando desconocido: {cmd}")
        sys.exit(1)
