#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
server_1bit.py - Servidor HTTP embebido con la interfaz 1-Bit Monocromo X11 (1984)
Accesible vía navegador en http://localhost:8080
"""
import http.server
import socketserver
import json
import urllib.parse
import os
import sys
from datetime import date, datetime, timedelta

# Importamos las funciones del backend ya probadas
import registro_diario_core as core

PORT = 8080

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>X11::JIRA_1BIT_CONSOLE (1984)</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: "Courier New", Courier, monospace;
      -webkit-font-smoothing: none;
    }
    body {
      background-color: #ffffff;
      color: #000000;
      padding: 10px;
      user-select: none;
    }
    /* Estilo del Scrollbar 1-bit Dithered */
    ::-webkit-scrollbar {
      width: 16px;
      background: #ffffff;
      border-left: 2px solid #000000;
    }
    ::-webkit-scrollbar-track {
      background: repeating-linear-gradient(
        45deg,
        #000000,
        #000000 1px,
        #ffffff 1px,
        #ffffff 3px
      );
    }
    ::-webkit-scrollbar-thumb {
      background: #000000;
      border: 2px solid #ffffff;
      outline: 1px solid #000000;
    }
    
    .window {
      border: 2px solid #000000;
      padding: 8px;
      margin-bottom: 8px;
    }
    .topbar {
      border: 2px solid #000000;
      padding: 6px 10px;
      margin-bottom: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #ffffff;
    }
    .topbar h1 {
      font-size: 14px;
      font-weight: bold;
    }
    .btn {
      background: #ffffff;
      color: #000000;
      border: 2px solid #000000;
      padding: 4px 10px;
      font-size: 12px;
      font-weight: bold;
      cursor: crosshair;
      text-decoration: none;
      display: inline-block;
    }
    .btn:hover, .btn:active, .btn.active {
      background: #000000;
      color: #ffffff;
    }
    .btn-primary {
      background: #000000;
      color: #ffffff;
    }
    .btn-primary:hover {
      background: #ffffff;
      color: #000000;
    }
    
    .layout {
      display: grid;
      grid-template-columns: 360px 1fr;
      gap: 8px;
      height: calc(100vh - 120px);
    }
    .panel {
      border: 2px solid #000000;
      padding: 8px;
      display: flex;
      flex-direction: column;
      background: #ffffff;
      overflow-y: auto;
    }
    .box-title {
      font-weight: bold;
      border-bottom: 2px solid #000000;
      padding-bottom: 4px;
      margin-bottom: 8px;
      font-size: 13px;
    }
    .total-large {
      font-size: 26px;
      font-weight: bold;
      margin: 4px 0;
    }
    .field-group {
      margin-bottom: 10px;
    }
    .field-group label {
      display: block;
      font-weight: bold;
      font-size: 11px;
      margin-bottom: 3px;
    }
    select, input[type="text"] {
      width: 100%;
      border: 2px solid #000000;
      background: #ffffff;
      color: #000000;
      padding: 4px;
      font-size: 12px;
      outline: none;
    }
    select:focus, input[type="text"]:focus {
      background: #000000;
      color: #ffffff;
    }
    
    .filter-bar {
      border: 1px solid #000000;
      padding: 4px 8px;
      margin-bottom: 6px;
      display: flex;
      gap: 12px;
      align-items: center;
    }
    .filter-bar select {
      width: auto;
    }
    .tables-container {
      display: grid;
      grid-template-rows: 1fr 1fr;
      gap: 8px;
      flex: 1;
      min-height: 0;
    }
    .table-box {
      border: 2px solid #000000;
      display: flex;
      flex-direction: column;
      min-height: 0;
    }
    .table-head {
      background: #000000;
      color: #ffffff;
      padding: 4px 6px;
      font-weight: bold;
      font-size: 12px;
      display: flex;
      justify-content: space-between;
    }
    .table-list {
      flex: 1;
      overflow-y: scroll;
      list-style: none;
      background: #ffffff;
    }
    .table-list li {
      padding: 4px 6px;
      border-bottom: 1px dotted #000000;
      font-size: 11px;
      cursor: crosshair;
      display: flex;
      justify-content: space-between;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .table-list li:hover {
      background: #000000;
      color: #ffffff;
    }
    .table-list li.selected {
      background: #000000;
      color: #ffffff;
      font-weight: bold;
    }
    .item-key { width: 100px; font-weight: bold; }
    .item-status { width: 120px; }
    .item-hours { width: 60px; text-align: right; margin-right: 10px; }
    .item-summary { flex: 1; overflow: hidden; text-overflow: ellipsis; }

    .bottom-bar {
      border: 2px solid #000000;
      padding: 6px 10px;
      margin-top: 8px;
      display: flex;
      justify-content: space-between;
    }
    .status-badge {
      font-weight: bold;
      padding: 2px 4px;
      border: 1px solid #000000;
      display: inline-block;
      margin-top: 4px;
    }
  </style>
</head>
<body>
  <div class="topbar">
    <h1>=== [ X11-1BIT::JIRA-CONSOLE WEB ] === <span id="curDate"></span> ===</h1>
    <div>
      <button class="btn" onclick="prevDay()">&lt; DIA_ANTERIOR</button>
      <button class="btn" onclick="goToday()">[ HOY ]</button>
      <button class="btn" onclick="nextDay()">DIA_SIGUIENTE &gt;</button>
      <button class="btn btn-primary" onclick="syncJira()">[!] SYNC_JIRA</button>
    </div>
  </div>

  <div class="layout">
    <!-- PANEL IZQUIERDO -->
    <div class="panel">
      <div class="box-title">+-- [ HORAS_JORNADA ] --+</div>
      <div class="total-large" id="totalHours">0h</div>
      <div id="subHours" style="font-size: 11px; margin-bottom: 6px;">Jira: 0h | Local: 0h</div>
      <div><span class="status-badge" id="statusBadge">[ CARGANDO... ]</span></div>
      
      <div class="box-title" style="margin-top: 14px;" id="modeTitle">+-- [ REGISTRO ] --+</div>
      <div id="selectedInfo" style="font-size: 11px; font-weight: bold; margin-bottom: 8px;">Selecciona una tarea o historia...</div>

      <div class="field-group">
        <label>TIEMPO A REGISTRAR:</label>
        <select id="timeQty">
          <option value="0.5">0.5 Horas (30 min)</option>
          <option value="1.0" selected>1.0 Horas (60 min)</option>
          <option value="1.5">1.5 Horas</option>
          <option value="2.0">2.0 Horas</option>
          <option value="2.5">2.5 Horas</option>
          <option value="3.0">3.0 Horas</option>
          <option value="4.0">4.0 Horas</option>
          <option value="8.0">8.0 Horas (Jornada)</option>
        </select>
      </div>

      <div class="field-group" id="actGroup">
        <label>ACTIVIDAD / CEREMONIA:</label>
        <select id="actType">
          <option value="Refinamiento">Refinamiento</option>
          <option value="Planning">Planning</option>
          <option value="Retrospectiva">Retrospectiva</option>
          <option value="Adicional">Adicional</option>
          <option value="Trabajo en tarea">Trabajo en tarea</option>
        </select>
      </div>

      <div class="field-group" id="detailGroup">
        <label>DETALLE / COMENTARIO:</label>
        <input type="text" id="detailText" placeholder="Descripción de la actividad...">
      </div>

      <button class="btn btn-primary" style="width: 100%; margin-bottom: 6px;" onclick="registerDirect()">[>>] REGISTRAR EN JIRA</button>
      <button class="btn" style="width: 100%;" onclick="insertLocal()">[+] GUARDAR EN COLA LOCAL</button>
    </div>

    <!-- PANEL DERECHO -->
    <div class="panel" style="padding: 0; background: transparent; border: none;">
      <div class="filter-bar">
        <span>PROYECTO:</span>
        <select id="projFilter" onchange="renderTables()"><option value="ALL">Todos los proyectos</option></select>
        <span>BUSCAR:</span>
        <input type="text" id="searchFilter" oninput="renderTables()" style="width: 140px;">
        <button class="btn" onclick="clearHUFilter()">[ VER_TODAS ]</button>
      </div>

      <div class="tables-container">
        <!-- TAREAS -->
        <div class="table-box">
          <div class="table-head">
            <span id="tasksHeader">== [ TAREAS ASIGNADAS ] =====================</span>
          </div>
          <ul class="table-list" id="tasksList"></ul>
        </div>

        <!-- HISTORIAS -->
        <div class="table-box">
          <div class="table-head">
            <span id="storiesHeader">== [ HISTORIAS DE USUARIO SPRINT ] ============</span>
          </div>
          <ul class="table-list" id="storiesList"></ul>
        </div>
      </div>
    </div>
  </div>

  <div class="bottom-bar">
    <div>
      <button class="btn btn-primary" onclick="printPDF()">[>>] IMPRIMIR_PDF (1 PAG/REG)</button>
    </div>
    <div style="font-size: 11px; align-self: center;">
      1-BIT MONOCHROME CONSOLE &copy; 1984 X11 INTERFACE
    </div>
  </div>

  <script>
    let currentDay = new Date().toISOString().slice(0,10);
    let allIssues = [];
    let worklogs = [];
    let selectedItem = null;
    let selectedType = 'task'; // 'task' | 'story'
    let selectedHUKey = null;

    async function loadData() {
      document.getElementById('curDate').innerText = currentDay;
      const res = await fetch(`/api/data?day=${currentDay}`);
      const data = await res.json();
      allIssues = data.issues || [];
      worklogs = data.worklogs || [];
      updateTotals(data.totals);
      updateProjectFilter();
      renderTables();
    }

    function updateTotals(totals) {
      const total = totals.total || 0;
      document.getElementById('totalHours').innerText = `${total}h`;
      document.getElementById('subHours').innerText = `Jira: ${totals.jira}h | Local: ${totals.local}h`;
      const badge = document.getElementById('statusBadge');
      if (total < 6.5) {
        badge.innerText = `[ FALTAN ${(6.5 - total).toFixed(1)}h ]`;
      } else if (total <= 10.5) {
        badge.innerText = `[ JORNADA COMPLETA OK ]`;
      } else {
        badge.innerText = `[ SOBREPASO: ${(total - 10.5).toFixed(1)}h ]`;
      }
    }

    function updateProjectFilter() {
      const sel = document.getElementById('projFilter');
      const current = sel.value;
      const projects = [...new Set(allIssues.map(i => i.project).filter(p => p && p !== '-'))];
      sel.innerHTML = '<option value="ALL">Todos los proyectos</option>';
      projects.forEach(p => {
        const opt = document.createElement('option');
        opt.value = p; opt.innerText = p;
        if (p === current) opt.selected = true;
        sel.appendChild(opt);
      });
    }

    function renderTables() {
      const pFilter = document.getElementById('projFilter').value;
      const sFilter = document.getElementById('searchFilter').value.toLowerCase();
      
      const tasksUl = document.getElementById('tasksList');
      const storiesUl = document.getElementById('storiesList');
      tasksUl.innerHTML = '';
      storiesUl.innerHTML = '';

      const tasks = allIssues.filter(i => !['Historia de usuario', 'Story', 'Historia'].includes(i.type));
      const stories = allIssues.filter(i => ['Historia de usuario', 'Story', 'Historia'].includes(i.type));

      // Filtrar tareas
      const filteredTasks = tasks.filter(t => {
        if (pFilter !== 'ALL' && t.project !== pFilter) return false;
        if (selectedHUKey && !(t.linked_stories || []).includes(selectedHUKey)) return false;
        if (sFilter && !`${t.key} ${t.summary} ${t.status}`.toLowerCase().includes(sFilter)) return false;
        return true;
      });

      filteredTasks.forEach(t => {
        const li = document.createElement('li');
        if (selectedItem && selectedItem.key === t.key) li.className = 'selected';
        li.innerHTML = `<span class="item-key">${t.key}</span><span class="item-status">[${t.status.slice(0,12)}]</span><span class="item-hours">${t.hours}</span><span class="item-summary">${t.summary}</span>`;
        li.onclick = () => selectItem(t, 'task');
        tasksUl.appendChild(li);
      });

      // Filtrar historias
      const filteredStories = stories.filter(s => {
        if (pFilter !== 'ALL' && s.project !== pFilter) return false;
        if (sFilter && !`${s.key} ${s.summary}`.toLowerCase().includes(sFilter)) return false;
        return true;
      });

      filteredStories.forEach(s => {
        const li = document.createElement('li');
        if (selectedHUKey === s.key) li.className = 'selected';
        li.innerHTML = `<span class="item-key">${s.key}</span><span class="item-status">[${s.status.slice(0,12)}]</span><span class="item-summary">${s.summary}</span>`;
        li.onclick = () => selectItem(s, 'story');
        storiesUl.appendChild(li);
      });
    }

    function selectItem(item, type) {
      selectedItem = item;
      selectedType = type;
      if (type === 'story') {
        selectedHUKey = item.key;
        document.getElementById('modeTitle').innerText = `+-- [ MODO::HISTORIA (${item.key}) ] --+`;
        document.getElementById('selectedInfo').innerText = `HU: ${item.key} - ${item.summary.slice(0,35)}...`;
      } else {
        document.getElementById('modeTitle').innerText = `+-- [ MODO::TAREA (${item.key}) ] --+`;
        document.getElementById('selectedInfo').innerText = `TAREA: ${item.key} - ${item.summary.slice(0,35)}...`;
      }
      renderTables();
    }

    function clearHUFilter() {
      selectedHUKey = null;
      renderTables();
    }

    function prevDay() {
      const d = new Date(currentDay); d.setDate(d.getDate() - 1);
      currentDay = d.toISOString().slice(0,10);
      loadData();
    }
    function nextDay() {
      const d = new Date(currentDay); d.setDate(d.getDate() + 1);
      const today = new Date().toISOString().slice(0,10);
      if (d.toISOString().slice(0,10) <= today) {
        currentDay = d.toISOString().slice(0,10);
        loadData();
      }
    }
    function goToday() {
      currentDay = new Date().toISOString().slice(0,10);
      loadData();
    }

    async function syncJira() {
      await fetch('/api/sync');
      loadData();
    }

    async function registerDirect() {
      if (!selectedItem) return alert("Selecciona una tarea o historia.");
      const hours = parseFloat(document.getElementById('timeQty').value);
      const activity = document.getElementById('actType').value;
      const detail = document.getElementById('detailText').value.trim();

      const conf = confirm(`¿Registrar ${hours}h en ${selectedItem.key}?`);
      if (!conf) return;

      const res = await fetch('/api/register', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          day: currentDay,
          key: selectedItem.key,
          type: selectedType,
          hours,
          activity,
          detail
        })
      });
      const result = await res.json();
      if (result.ok) {
        alert("¡Registrado exitosamente!");
        document.getElementById('detailText').value = '';
        loadData();
      } else {
        alert(`Error: ${result.error}`);
      }
    }

    async function insertLocal() {
      if (!selectedItem) return alert("Selecciona una tarea o historia.");
      const hours = parseFloat(document.getElementById('timeQty').value);
      const activity = document.getElementById('actType').value;
      const detail = document.getElementById('detailText').value.trim();

      const res = await fetch('/api/insert_local', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          day: currentDay,
          key: selectedItem.key,
          hours,
          activity: detail || activity
        })
      });
      loadData();
    }

    function printPDF() {
      fetch(`/api/pdf?day=${currentDay}`);
      alert("Proceso de generación de PDF lanzado en segundo plano.");
    }

    loadData();
  </script>
</body>
</html>
"""


class JiraHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
            return

        if parsed.path == "/api/data":
            query = urllib.parse.parse_qs(parsed.query)
            target_day = query.get("day", [date.today().isoformat()])[0]

            config = core.read_config()
            issues = core.get_cached_issues(config)
            worklogs = core.get_cached_worklogs(config, target_day)
            state = core.load_state()
            curr_state = core.day_state(state, target_day)

            jira_total = sum(float(w.get("hours", 0)) for w in worklogs)
            local_total = sum(float(w.get("hours", 0)) for w in curr_state.get("worklogs", []))

            resp = {
                "day": target_day,
                "issues": issues,
                "worklogs": worklogs,
                "totals": {
                    "jira": round(jira_total, 2),
                    "local": round(local_total, 2),
                    "total": round(jira_total + local_total, 2)
                }
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        if parsed.path == "/api/sync":
            config = core.read_config()
            core.refresh_cache(config)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')
            return

        if parsed.path == "/api/pdf":
            query = urllib.parse.parse_qs(parsed.query)
            target_day = query.get("day", [date.today().isoformat()])[0]
            config = core.read_config()
            subprocess.Popen([sys.executable, "/home/user/monoliths-llm/registro-diario-1bit.py", "--generate-pdf-bg", target_day],
                             start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')
            return

        self.send_error(404, "Not found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        content_len = int(self.headers.get("Content-Length", 0))
        post_body = self.rfile.read(content_len)
        data = json.loads(post_body.decode("utf-8"))

        if parsed.path == "/api/register":
            config = core.read_config()
            target_key = data.get("key")
            hours = float(data.get("hours", 1.0))
            activity = data.get("activity", "Trabajo en tarea")
            detail = data.get("detail", "")
            is_story = data.get("type") == "story"

            try:
                if is_story:
                    story_issue = next((i for i in core.get_cached_issues(config) if i["key"] == target_key), None)
                    new_key, _ = core.create_task_for_story(config, story_issue, activity, detail or activity)
                    target_key = new_key

                url = core.register_in_jira(config, target_key, hours, activity, detail or activity)
                core.clear_worklogs_cache(data.get("day"))
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"ok": True, "url": url}).encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
            return

        if parsed.path == "/api/insert_local":
            target_day = data.get("day")
            state = core.load_state()
            curr_state = core.day_state(state, target_day)
            curr_state["worklogs"].append({
                "key": data.get("key"),
                "summary": data.get("activity"),
                "hours": float(data.get("hours", 1.0)),
                "activity": data.get("activity"),
                "created": datetime.now().isoformat(timespec="seconds")
            })
            core.save_state(state)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')
            return

        self.send_error(404, "Not found")


def main():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), JiraHandler) as httpd:
        print(f"[*] Servidor 1-Bit Web corriendo en http://localhost:{PORT}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
