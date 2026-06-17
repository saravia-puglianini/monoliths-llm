const MEET_URL = 'https://meet.google.com/landing?authuser=1';
const CALENDAR_URL = 'https://calendar.google.com/calendar/u/1/r';

let state = {
  meetTab: null,
  calendarTab: null
};

// UI Elements
const statusMeetEl = document.getElementById('status-meet');
const statusCalendarEl = document.getElementById('status-calendar');
const btnMeetEl = document.getElementById('btn-meet');
const btnCalendarEl = document.getElementById('btn-calendar');
const btnSyncAllEl = document.getElementById('btn-sync-all');

// Helper to determine if a tab matches our target URL
function matchMeet(url) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    return parsed.hostname === 'meet.google.com' &&
      (parsed.pathname === '/landing' || parsed.pathname === '/') &&
      parsed.searchParams.get('authuser') === '1';
  } catch (e) {
    return url.includes('meet.google.com/landing?authuser=1');
  }
}

function matchCalendar(url) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    return parsed.hostname === 'calendar.google.com' &&
      (parsed.pathname.includes('/u/1') || parsed.pathname.includes('/calendar/u/1'));
  } catch (e) {
    return url.includes('calendar.google.com/calendar/u/1');
  }
}

// Check open tabs and update UI
async function checkTabs() {
  updateStatusUI(statusMeetEl, 'checking', 'Comprobando...');
  updateStatusUI(statusCalendarEl, 'checking', 'Comprobando...');

  try {
    const tabs = await chrome.tabs.query({});

    state.meetTab = tabs.find(tab => matchMeet(tab.url)) || null;
    state.calendarTab = tabs.find(tab => matchCalendar(tab.url)) || null;

    // Update Meet UI
    if (state.meetTab) {
      updateStatusUI(statusMeetEl, 'open', 'Abierto');
      btnMeetEl.textContent = 'Enfocar Pestaña';
      btnMeetEl.className = 'btn btn-secondary';
    } else {
      updateStatusUI(statusMeetEl, 'closed', 'Cerrado');
      btnMeetEl.textContent = 'Abrir en Pestaña';
      btnMeetEl.className = 'btn btn-primary';
    }
    btnMeetEl.disabled = false;

    // Update Calendar UI
    if (state.calendarTab) {
      updateStatusUI(statusCalendarEl, 'open', 'Abierto');
      btnCalendarEl.textContent = 'Enfocar Pestaña';
      btnCalendarEl.className = 'btn btn-secondary';
    } else {
      updateStatusUI(statusCalendarEl, 'closed', 'Cerrado');
      btnCalendarEl.textContent = 'Abrir en Pestaña';
      btnCalendarEl.className = 'btn btn-primary';
    }
    btnCalendarEl.disabled = false;

  } catch (error) {
    console.error('Error al consultar las pestañas:', error);
    updateStatusUI(statusMeetEl, 'closed', 'Error');
    updateStatusUI(statusCalendarEl, 'closed', 'Error');
  }
}

function updateStatusUI(element, statusClass, text) {
  element.className = `status-indicator ${statusClass}`;
  element.querySelector('.text').textContent = text;
}

// Action helper to focus or open
async function handleTabAction(tab, targetUrl) {
  if (tab && tab.id) {
    // Focus existing tab
    await chrome.tabs.update(tab.id, { active: true });
    if (tab.windowId) {
      await chrome.windows.update(tab.windowId, { focused: true });
    }
  } else {
    // Open new tab
    await chrome.tabs.create({ url: targetUrl });
  }
  await checkTabs();
}

// Event Listeners
btnMeetEl.addEventListener('click', () => {
  handleTabAction(state.meetTab, MEET_URL);
});

btnCalendarEl.addEventListener('click', () => {
  handleTabAction(state.calendarTab, CALENDAR_URL);
});

btnSyncAllEl.addEventListener('click', async () => {
  btnSyncAllEl.disabled = true;

  // Verify and open Meet if closed
  if (!state.meetTab) {
    await chrome.tabs.create({ url: MEET_URL });
  } else {
    // If open, just focus it
    await chrome.tabs.update(state.meetTab.id, { active: true });
    if (state.meetTab.windowId) {
      await chrome.windows.update(state.meetTab.windowId, { focused: true });
    }
  }

  // Verify and open Calendar if closed
  if (!state.calendarTab) {
    await chrome.tabs.create({ url: CALENDAR_URL });
  } else {
    // If open, focus it
    await chrome.tabs.update(state.calendarTab.id, { active: true });
    if (state.calendarTab.windowId) {
      await chrome.windows.update(state.calendarTab.windowId, { focused: true });
    }
  }

  await checkTabs();
  btnSyncAllEl.disabled = false;
});

async function checkDynamicPermissions() {
  const banner = document.getElementById('permission-banner');
  const desc = document.getElementById('permission-desc');
  const grantBtn = document.getElementById('btn-grant-permissions');
  
  if (!banner) return;
  
  try {
    const csvUrl = chrome.runtime.getURL('preferencias.csv');
    const response = await fetch(`${csvUrl}?_t=${Date.now()}`, { cache: 'no-cache' });
    if (!response.ok) return;
    const csvText = await response.text();
    
    const lines = csvText.split('\n');
    const origins = new Set();
    
    for (let line of lines) {
      line = line.trim();
      if (!line) continue;
      const parts = line.split(',');
      if (parts.length >= 2) {
        try {
          const urlStr = parts[1].trim();
          const urlObj = new URL(urlStr);
          origins.add(`${urlObj.protocol}//${urlObj.hostname}/*`);
        } catch (e) {
          // Ignore invalid URL
        }
      }
    }
    
    const originsArray = Array.from(origins);
    if (originsArray.length === 0) {
      banner.classList.add('hidden');
      return;
    }
    
    const missingOrigins = [];
    for (const origin of originsArray) {
      const hasPerm = await chrome.permissions.contains({ origins: [origin] });
      if (!hasPerm) {
        missingOrigins.push(origin);
      }
    }
    
    if (missingOrigins.length > 0) {
      const domains = missingOrigins.map(o => {
        try {
          return new URL(o.replace('/*', '')).hostname;
        } catch (e) {
          return o;
        }
      });
      desc.textContent = `Se necesita acceso para: ${domains.join(', ')}`;
      banner.classList.remove('hidden');
      
      grantBtn.onclick = async () => {
        try {
          const granted = await chrome.permissions.request({ origins: missingOrigins });
          if (granted) {
            banner.classList.add('hidden');
            await checkTabs();
          }
        } catch (err) {
          console.error('Error requesting permissions:', err);
        }
      };
    } else {
      banner.classList.add('hidden');
    }
  } catch (err) {
    console.error('Error checking dynamic permissions:', err);
  }
}

// Initialize on popup load
document.addEventListener('DOMContentLoaded', async () => {
  await checkDynamicPermissions();
  await checkTabs();
  
  // Load and bind auto-reopen checkbox
  const chkAutoReopen = document.getElementById('chk-auto-reopen');
  if (chkAutoReopen) {
    const { autoReopen = true } = await chrome.storage.local.get('autoReopen');
    chkAutoReopen.checked = autoReopen;
    
    chkAutoReopen.addEventListener('change', async (e) => {
      await chrome.storage.local.set({ autoReopen: e.target.checked });
    });
  }
});
