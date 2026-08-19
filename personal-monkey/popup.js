document.addEventListener('DOMContentLoaded', async () => {
  const numOffHours = document.getElementById('num-off-hours');
  const btnTogglePause = document.getElementById('btn-toggle-pause');
  const pauseStatusText = document.getElementById('pause-status-text');

  async function updateUI() {
    const { pauseUntil = 0, offHours = 1 } = await chrome.storage.local.get(['pauseUntil', 'offHours']);
    numOffHours.value = offHours;

    const now = Date.now();
    if (pauseUntil && pauseUntil > now) {
      const remainingMin = Math.round((pauseUntil - now) / 60000);
      const dateStr = new Date(pauseUntil).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      pauseStatusText.textContent = `Pausado hasta las ${dateStr} (~${remainingMin}m)`;
      pauseStatusText.style.color = '#f87171';
      btnTogglePause.textContent = '▶️ Reanudar Addon';
      btnTogglePause.className = 'btn btn-resume';
    } else {
      pauseStatusText.textContent = 'Estado: Activo';
      pauseStatusText.style.color = '#38bdf8';
      const hours = numOffHours.value || 1;
      btnTogglePause.textContent = `⏸️ Pausar por ${hours} hora(s)`;
      btnTogglePause.className = 'btn btn-pause';
    }
  }

  numOffHours.addEventListener('input', async (e) => {
    const val = parseFloat(e.target.value) || 1;
    await chrome.storage.local.set({ offHours: val });
    updateUI();
  });

  btnTogglePause.addEventListener('click', async () => {
    const { pauseUntil = 0 } = await chrome.storage.local.get('pauseUntil');
    const now = Date.now();
    if (pauseUntil && pauseUntil > now) {
      await chrome.storage.local.set({ pauseUntil: 0 });
    } else {
      const hours = parseFloat(numOffHours.value) || 1;
      const targetTime = now + (hours * 3600 * 1000);
      await chrome.storage.local.set({ pauseUntil: targetTime });
    }
    await updateUI();
  });

  await updateUI();
  setInterval(updateUI, 5000);
});
