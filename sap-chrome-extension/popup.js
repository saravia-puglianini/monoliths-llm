document.addEventListener("DOMContentLoaded", () => {
  checkStatus();
  document.getElementById("btnCheck").addEventListener("click", () => {
    const statusBadge = document.getElementById("serverStatus");
    statusBadge.textContent = "Ejecutando...";
    statusBadge.className = "status-badge badge-pending";
    
    chrome.runtime.sendMessage({ action: "TRIGGER_CHECK_NOW" }, () => {
      setTimeout(checkStatus, 1000);
    });
  });
});

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
