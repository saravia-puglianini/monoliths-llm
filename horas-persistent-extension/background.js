const APP_URL = 'http://localhost:8085/';
const CHECK_ALARM = 'comprobar-horas';

let checking = null;

function isWeekday() {
  const day = new Date().getDay();
  return day >= 1 && day <= 5;
}

function isAppTab(tab) {
  if (!tab.url) return false;
  const cleanUrl = tab.url.split(/[?#]/, 1)[0].replace(/\/$/, '');
  return cleanUrl === 'http://localhost:8085' || cleanUrl === 'http://127.0.0.1:8085' || cleanUrl === 'https://saravia.org/registro-diario.htm';
}

async function findAppTabs() {
  const tabs = await chrome.tabs.query({});
  return tabs.filter(isAppTab);
}

async function ensureAppTab({ focus = false, force = false } = {}) {
  if (!force && !isWeekday()) return null;
  if (checking) return checking;

  checking = (async () => {
    const matches = await findAppTabs();
    let tab = matches[0];

    if (!tab) {
      tab = await chrome.tabs.create({
        url: APP_URL,
        active: focus,
        pinned: false
      });
    } else {
      const changes = {};
      if (tab.pinned) changes.pinned = false;
      if (focus) changes.active = true;
      if (Object.keys(changes).length) {
        tab = await chrome.tabs.update(tab.id, changes);
      }
    }

    if (focus && tab.windowId !== undefined) {
      await chrome.windows.update(tab.windowId, { focused: true });
    }

    return tab;
  })().catch(error => {
    console.error('No se pudo mantener abierta la pestaña de Horas:', error);
    return null;
  }).finally(() => {
    checking = null;
  });

  return checking;
}

async function installAlarm() {
  await chrome.alarms.clear(CHECK_ALARM);
  chrome.alarms.create(CHECK_ALARM, {
    delayInMinutes: 0.1,
    periodInMinutes: 1
  });
}

chrome.runtime.onInstalled.addListener(() => {
  installAlarm();
  ensureAppTab();
});

chrome.runtime.onStartup.addListener(() => {
  installAlarm();
  ensureAppTab();
});

chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === CHECK_ALARM) ensureAppTab();
});

chrome.tabs.onRemoved.addListener(() => {
  ensureAppTab();
});

chrome.tabs.onUpdated.addListener((_tabId, changeInfo) => {
  if (changeInfo.url) ensureAppTab();
});

chrome.action.onClicked.addListener(() => {
  ensureAppTab({ focus: true, force: true });
});

installAlarm();
ensureAppTab();

function validateCredentials({ domain, email, token }) {
  const url = new URL(domain);
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.atlassian.net')) {
    throw new Error('El dominio configurado no está permitido.');
  }
  if (!email || !token) throw new Error('Faltan los datos de acceso.');
  return { domain: url.origin, email, token };
}

function validateAccess({ domain, email, token, issueKeys, date }) {
  const credentials = validateCredentials({ domain, email, token });
  if (!Array.isArray(issueKeys) || !issueKeys.length || issueKeys.some(key => !/^[A-Z][A-Z0-9]+-\d+$/.test(key))) {
    throw new Error('La lista de tareas no es válida.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error('La fecha no es válida.');
  return { ...credentials, issueKeys: [...new Set(issueKeys)], date };
}

async function fetchJson(url, authorization, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', Authorization: authorization, ...options.headers }
  });
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) throw new Error('Las credenciales fueron rechazadas. Revisa el correo y la key.');
    throw new Error(`El servicio respondió con el estado ${response.status}.`);
  }
  return response.json();
}

async function fetchAssignedIssues(payload) {
  const { domain, email, token } = validateCredentials(payload);
  const authorization = `Basic ${btoa(`${email}:${token}`)}`;
  const jql = 'assignee = currentUser() AND (statusCategory != Done OR status = "En medición") AND issuetype in (Task, Tarea, "Sub-task", Subtarea, Correctivos, "Error en producción", Incidencias) ORDER BY updated DESC';
  const data = await fetchJson(`${domain}/rest/api/3/search/jql`, authorization, {
    method: 'POST',
    body: JSON.stringify({ jql, maxResults: 50, fields: ['key', 'summary', 'project', 'parent', 'status', 'duedate', 'timespent', 'aggregatetimespent'] })
  });
  return (data.issues || []).map(issue => {
    const fields = issue.fields || {}, parent = fields.parent || {};
    return {
      key: issue.key,
      summary: fields.summary || 'Sin título',
      status: fields.status?.name || 'Sin estado',
      dueDate: fields.duedate || null,
      hours: (fields.timespent || fields.aggregatetimespent || 0) / 3600,
      projectKey: fields.project?.key || issue.key.split('-')[0],
      projectName: fields.project?.name || 'Proyecto',
      parentKey: parent.key || null,
      parentSummary: parent.fields?.summary || null
    };
  });
}

async function fetchTodayRecords(payload) {
  const { domain, email, token, issueKeys, date } = validateAccess(payload);
  const authorization = `Basic ${btoa(`${email}:${token}`)}`;
  const me = await fetchJson(`${domain}/rest/api/3/myself`, authorization);
  const groups = await Promise.all(issueKeys.map(async key => {
    const data = await fetchJson(`${domain}/rest/api/3/issue/${encodeURIComponent(key)}/worklog?maxResults=5000`, authorization);
    return (data.worklogs || [])
      .filter(item => item.author?.accountId === me.accountId && String(item.started || '').slice(0, 10) === date)
      .map(item => ({ key, id: String(item.id), hours: (item.timeSpentSeconds || 0) / 3600, started: item.started }));
  }));
  return groups.flat().sort((a, b) => String(a.started).localeCompare(String(b.started)));
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!['HORAS_GET_TODAY_RECORDS', 'HORAS_GET_ASSIGNED_ISSUES'].includes(message?.type)) return false;
  const senderUrl = sender.tab?.url || '';
  if (!senderUrl.includes('localhost:8085') && !senderUrl.includes('127.0.0.1:8085') && !senderUrl.startsWith('https://saravia.org')) {
    sendResponse({ ok: false, error: 'Origen no autorizado.' });
    return false;
  }
  const request = message.type === 'HORAS_GET_ASSIGNED_ISSUES' ? fetchAssignedIssues : fetchTodayRecords;
  request(message.payload)
    .then(records => sendResponse({ ok: true, records }))
    .catch(error => sendResponse({ ok: false, error: error.message || 'No se pudo completar la consulta.' }));
  return true;
});
