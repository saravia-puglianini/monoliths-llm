async function runCheck() {
  try {
    const now = new Date();
    const day = now.getDay(); // 0 is Sunday, 6 is Saturday
    if (day === 0 || day === 6) {
      return;
    }
    const csvUrl = chrome.runtime.getURL('preferencias.csv');
    const response = await fetch(`${csvUrl}?_t=${Date.now()}`, { cache: 'no-cache' });
    if (!response.ok) {
      console.error('Failed to fetch preferencias.csv');
      return;
    }
    const csvText = await response.text();
    const rows = parseCSV(csvText);
    
    // Find rows that are currently active
    const activeRows = [];
    for (const row of rows) {
      if (isCurrentTimeInRange(row.timeRange, now)) {
        activeRows.push(row);
      }
    }
    
    if (activeRows.length === 0) {
      return;
    }
    
    // Send active rows to background service worker to process centrally
    chrome.runtime.sendMessage({
      type: 'PROCESS_ACTIVE_ROWS',
      rows: activeRows
    });
    
  } catch (err) {
    console.error('Error in offscreen interval checker:', err);
  }
}

function parseCSV(csvText) {
  const lines = csvText.split('\n');
  const records = [];
  for (let line of lines) {
    line = line.trim();
    if (!line) continue;
    
    // Handle CSV split, take care of possible commas inside text
    const parts = line.split(',');
    if (parts.length >= 2) {
      const timeRange = parts[0].trim();
      const url = parts[1].trim();
      const text = parts.slice(2).join(',').trim();
      records.push({ timeRange, url, text });
    }
  }
  return records;
}

function getMinutesFromMidnight(timeStr) {
  const parts = timeStr.split(':');
  if (parts.length < 2) return 0;
  let hour = parseInt(parts[0], 10);
  const minute = parseInt(parts[1], 10);
  
  // Heuristic: 1:00 to 6:00 are PM (13:00 to 18:00), 9:00 is AM (9:00)
  if (hour >= 1 && hour <= 6) {
    hour += 12;
  }
  return hour * 60 + minute;
}

function isCurrentTimeInRange(timeRange, now) {
  const parts = timeRange.split('-');
  if (parts.length !== 2) return false;
  
  const startStr = parts[0].trim();
  const endStr = parts[1].trim();
  
  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  
  const startMinutes = getMinutesFromMidnight(startStr);
  const endMinutes = getMinutesFromMidnight(endStr);
  
  if (startMinutes <= endMinutes) {
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  } else {
    // If end is less than start, it crosses midnight
    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  }
}

// Start interval every 5 seconds
setInterval(runCheck, 5000);
// Also run immediately on load
runCheck();

// Send a heartbeat message to the service worker every 20 seconds to keep it active
setInterval(() => {
  chrome.runtime.sendMessage({ type: 'keepAlive' }).catch(() => {
    // Ignore error if SW is deactivating or not ready
  });
}, 20000);
