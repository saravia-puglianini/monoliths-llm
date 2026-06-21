const MEET_URL = 'https://meet.google.com/landing?authuser=1';
const CALENDAR_URL = 'https://calendar.google.com/calendar/u/1/r';

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

// General helper to check if tab URL matches target URL from CSV
function urlsMatch(urlA, urlB) {
  if (!urlA || !urlB) return false;
  try {
    const a = new URL(urlA);
    const b = new URL(urlB);
    
    // Check authuser parameter first (if both have authuser, they must match)
    const authA = a.searchParams.get('authuser') || (a.pathname.match(/\/u\/(\d+)/) || [])[1];
    const authB = b.searchParams.get('authuser') || (b.pathname.match(/\/u\/(\d+)/) || [])[1];
    if (authA && authB && authA !== authB) {
      return false;
    }
    
    // Check if both are Google Meet landing/home pages
    const isMeetLandingA = a.hostname === 'meet.google.com' && (a.pathname === '/landing' || a.pathname === '/' || a.pathname === '');
    const isMeetLandingB = b.hostname === 'meet.google.com' && (b.pathname === '/landing' || b.pathname === '/' || b.pathname === '');
    if (isMeetLandingA && isMeetLandingB) {
      return true;
    }
    
    // Check if both are Google Calendar tabs
    const isCalendarA = a.hostname === 'calendar.google.com';
    const isCalendarB = b.hostname === 'calendar.google.com';
    if (isCalendarA && isCalendarB) {
      return true;
    }
    
    // General match
    const hostMatch = a.hostname === 'meet.google.com' && b.hostname === 'meet.google.com' ? true : a.hostname === b.hostname;
    const pathMatch = a.pathname.replace(/\/$/, '') === b.pathname.replace(/\/$/, '');
    
    return hostMatch && pathMatch;
  } catch (e) {
    return urlA === urlB;
  }
}

// Offscreen Document Management
async function createOffscreen() {
  try {
    const existingContexts = await chrome.runtime.getContexts({
      contextTypes: ['OFFSCREEN_DOCUMENT']
    });
    if (existingContexts.length > 0) return;
  } catch (e) {
    // Fallback if getContexts is not supported
    if (await chrome.offscreen.hasDocument?.()) return;
  }
  
  try {
    await chrome.offscreen.createDocument({
      url: 'offscreen.html',
      reasons: ['AUDIO_PLAYBACK'],
      justification: 'Periodic tab checker and text-to-speech speaker'
    });
  } catch (err) {
    console.error('Failed to create offscreen document:', err);
  }
}

async function setupAlarms() {
  await createOffscreen();
  chrome.alarms.create('keepAliveAlarm', { periodInMinutes: 1 });
}

chrome.runtime.onStartup.addListener(setupAlarms);
chrome.runtime.onInstalled.addListener(setupAlarms);

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'keepAliveAlarm') {
    console.log('Keep alive alarm triggered');
    await createOffscreen();
  }
});

// Re-check/ensure offscreen document is alive on periodic service worker activations
chrome.tabs.onActivated.addListener(createOffscreen);

// Run immediately when service worker starts
setupAlarms();

// Helper to speak a text
function speakText(text) {
  const textToSpeak = text ? `Ingresando automáticamente a ${text}` : 'Ingresando automáticamente';
  fetch('http://localhost:5005/speak', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ text: textToSpeak })
  }).then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
  }).catch(err => {
    console.warn('Local Python TTS server not running or failed. Falling back to chrome.tts. Error:', err);
    try {
      chrome.tts.speak(textToSpeak, { lang: 'es-ES' });
      chrome.tts.speak("repito.", { lang: 'es-ES', enqueue: true });
      chrome.tts.speak(textToSpeak, { lang: 'es-ES', enqueue: true });
    } catch (e) {
      console.error('Fallback chrome.tts error:', e);
    }
  });
}

// Message listener to handle active rows from offscreen script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'keepAlive') {
    console.log('Keep-alive heartbeat received');
    sendResponse({ success: true });
    return true;
  }
  if (message.type === 'PROCESS_ACTIVE_ROWS') {
    (async () => {
      try {
        const now = new Date();
        const day = now.getDay(); // 0 is Sunday, 6 is Saturday
        if (day === 0 || day === 6) {
          sendResponse({ success: true, message: 'Skipped on weekend' });
          return;
        }
        
        const tabs = await chrome.tabs.query({});
        const { executedKeys = {}, autoReopen = true } = await chrome.storage.local.get(['executedKeys', 'autoReopen']);
        
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const todayStr = `${year}-${month}-${day}`;
        
        // Clean up keys from previous days to save space
        const updatedExecutedKeys = {};
        for (const key in executedKeys) {
          if (key.startsWith(todayStr)) {
            updatedExecutedKeys[key] = executedKeys[key];
          }
        }
        
        let storageUpdated = false;
        
        for (const row of message.rows) {
          const key = `${todayStr}_${row.timeRange}_${row.url}`;
          const isOpen = tabs.some(tab => urlsMatch(tab.url, row.url));
          
          if (isOpen) {
            // If it is already open, mark it as executed and speak the announcement if not done yet
            if (!updatedExecutedKeys[key]) {
              updatedExecutedKeys[key] = true;
              storageUpdated = true;
              speakText(row.text);
            }
          } else {
            // If it is closed and has not been executed yet today in this time range
            if (!updatedExecutedKeys[key]) {
              updatedExecutedKeys[key] = true;
              storageUpdated = true;
              
              // Speak the announcement
              speakText(row.text);
              
              // Open the tab
              await chrome.tabs.create({ url: row.url });
            } else if (autoReopen) {
              // Reopen silently if autoReopen is enabled
              await chrome.tabs.create({ url: row.url });
            }
          }
        }
        
        if (storageUpdated) {
          await chrome.storage.local.set({ executedKeys: updatedExecutedKeys });
        }
        
        sendResponse({ success: true });
      } catch (err) {
        console.error('Error processing active rows in background:', err);
        sendResponse({ success: false, error: err.message });
      }
    })();
    return true; // Keep channel open for async response
  }
});

// The periodic checker in offscreen.js ensures active URLs from preferencias.csv are open.

