document.addEventListener("DOMContentLoaded", () => {
  checkStatus();
  initPauseControls();
  document.getElementById("btnCheck").addEventListener("click", () => {
    const statusBadge = document.getElementById("serverStatus");
    statusBadge.textContent = "Ejecutando...";
    statusBadge.className = "status-badge badge-pending";
    
    chrome.runtime.sendMessage({ action: "TRIGGER_CHECK_NOW" }, () => {
      setTimeout(checkStatus, 1000);
    });
  });
});

async function updatePauseUI() {
  const statusEl = document.getElementById("pauseStatusSap");
  const btnToggle = document.getElementById("btnTogglePause");
  const numInput = document.getElementById("numOffHours");
  if (!statusEl || !btnToggle) return;

  const { pauseUntil = 0 } = await chrome.storage.local.get("pauseUntil");
  const now = Date.now();

  if (pauseUntil && pauseUntil > now) {
    const remainingMin = Math.round((pauseUntil - now) / 60000);
    const dateStr = new Date(pauseUntil).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    statusEl.textContent = `Pausado hasta las ${dateStr} (~${remainingMin}m)`;
    statusEl.style.color = "#f87171";
    btnToggle.textContent = "▶️ Reanudar Addon";
    btnToggle.style.background = "#059669";
  } else {
    statusEl.textContent = "Estado: Activo";
    statusEl.style.color = "#94a3b8";
    const hours = numInput ? numInput.value || 1 : 1;
    btnToggle.textContent = `⏸️ Pausar por ${hours} hora(s)`;
    btnToggle.style.background = "#475569";
  }
}

async function initPauseControls() {
  const numInput = document.getElementById("numOffHours");
  const btnToggle = document.getElementById("btnTogglePause");
  if (!numInput || !btnToggle) return;

  const { offHours = 1 } = await chrome.storage.local.get("offHours");
  numInput.value = offHours;

  numInput.addEventListener("input", async (e) => {
    const val = parseFloat(e.target.value) || 1;
    await chrome.storage.local.set({ offHours: val });
    updatePauseUI();
  });

  btnToggle.addEventListener("click", async () => {
    const { pauseUntil = 0 } = await chrome.storage.local.get("pauseUntil");
    const now = Date.now();
    if (pauseUntil && pauseUntil > now) {
      await chrome.storage.local.set({ pauseUntil: 0 });
    } else {
      const hours = parseFloat(numInput.value) || 1;
      const targetTime = now + (hours * 3600 * 1000);
      await chrome.storage.local.set({ pauseUntil: targetTime });
    }
    await updatePauseUI();
  });

  await updatePauseUI();
  setInterval(updatePauseUI, 5000);
}

function checkStatus() {
  const statusBadge = document.getElementById("serverStatus");
  const cargaStatus = document.getElementById("cargaStatus");
  const cargaDetails = document.getElementById("cargaDetails");

  try {
    chrome.runtime.sendMessage({ action: "GET_STATUS" }, (response) => {
      if (chrome.runtime.lastError || !response || !response.connected) {
        statusBadge.textContent = "Desconectado";
        statusBadge.className = "status-badge badge-pending";
        cargaStatus.textContent = "Servidor OpenRC :9995 no responde";
        cargaDetails.textContent = "Verifique que auto-erase-sap-carga.py esté activo.";
        return;
      }

      statusBadge.textContent = "Conectado :9995";
      statusBadge.className = "status-badge badge-ok";

      const data = response.data;
      if (data && data.pending && data.items && data.items.length > 0) {
        cargaStatus.textContent = `Pendiente (${data.fecha}) - ${data.items.length} tarea(s)`;
        cargaDetails.innerHTML = data.items.map(i => `• [${i.proyecto}] ${i.descripcion || 'Sin desc'}`).join("<br>");
      } else {
        cargaStatus.textContent = "Sin cargas pendientes (ready)";
        cargaDetails.textContent = "No hay archivo private.carga.txt pendiente.";
      }
    });
  } catch (e) {
    statusBadge.textContent = "Desconectado";
    statusBadge.className = "status-badge badge-pending";
  }
}
