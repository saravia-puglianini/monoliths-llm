// Background Service Worker para Auto SAP Worklog Integrator (CSP-Safe)
const SERVER_URL = "http://127.0.0.1:9995";
const SAP_TARGET_URL = "https://my419950.s4hana.cloud.sap/ui#TimeEntry-manageTimeEntry";

let isProcessing = false;

chrome.alarms.create("checkCargaAlarm", { periodInMinutes: 0.15 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "checkCargaAlarm") {
    checkPendingCarga();
  }
});

chrome.runtime.onInstalled.addListener(() => {
  console.log("🚀 [Auto SAP Extension] Background Worker iniciado.");
  checkPendingCarga();
});

async function checkPendingCarga() {
  if (isProcessing) return;

  try {
    const res = await fetch(`${SERVER_URL}/get-carga`);
    if (!res.ok) return;

    const data = await res.json();
    if (data.pending && data.items && data.items.length > 0) {
      console.log("⚡ [Auto SAP Background] Carga pendiente encontrada:", data);
      isProcessing = true;
      await processCargaInSAP(data);
    }
  } catch (err) {
    // Servidor 9995 no responde temporalmente
  }
}

async function processCargaInSAP(cargaData) {
  const tabs = await chrome.tabs.query({});
  let sapTab = tabs.find(t => t.url && t.url.includes("s4hana.cloud.sap"));

  if (!sapTab) {
    console.log("🌐 [Auto SAP Background] Abriendo pestaña de SAP en una pestaña nueva...");
    sapTab = await chrome.tabs.create({
      url: SAP_TARGET_URL,
      active: false
    });
  }

  const tabId = sapTab.id;

  // Esperar a que la pestaña termine de cargar
  const waitForTabLoad = (tId) => new Promise((resolve) => {
    const listener = (updatedTabId, changeInfo) => {
      if (updatedTabId === tId && changeInfo.status === "complete") {
        chrome.tabs.onUpdated.removeListener(listener);
        resolve();
      }
    };
    chrome.tabs.onUpdated.addListener(listener);
    setTimeout(resolve, 6000); // Timeout máximo
  });

  await waitForTabLoad(tabId);

  // Obtener URL actualizada
  const currentTab = await chrome.tabs.get(tabId);
  const currentUrl = currentTab.url || "";

  // Verificar si la sesión requiere inicio de sesión en Office/Microsoft/Login
  if (currentUrl.includes("office.com") || currentUrl.includes("microsoftonline") || currentUrl.includes("login") || currentUrl.includes("saml")) {
    console.warn("⚠️ [Auto SAP Background] Sesión no activa (página de login detectada):", currentUrl);
    chrome.notifications.create("loginNotice", {
      type: "basic",
      iconUrl: "icon.png",
      title: "Registro SAP - Requiere Iniciar Sesión",
      message: "Por favor inicia sesión en Office/SAP para realizar el registro automático de horas.",
      priority: 2
    });
    isProcessing = false;
    return;
  }

  try {
    await chrome.scripting.executeScript({
      target: { tabId: tabId },
      files: ["content_sap.js"]
    });
  } catch (e) {
    console.log("ℹ️ Content script ya presente o inyectado.");
  }

  setTimeout(() => {
    chrome.tabs.sendMessage(tabId, {
      action: "EXECUTE_CARGA_PAYLOAD",
      payload: cargaData
    }, (res) => {
      if (chrome.runtime.lastError) {
        console.error("❌ Error enviando payload a content_sap.js:", chrome.runtime.lastError.message);
        isProcessing = false;
      }
    });
  }, 2000);
}

async function notifyServerComplete() {
  try {
    const res = await fetch(`${SERVER_URL}/auto-erase-carga`, {
      method: "POST",
      headers: { "Content-Type": "application/json" }
    });
    const resData = await res.json();
    console.log("🎉 [Auto SAP Background] Servidor OpenRC rotó carga a ready:", resData);

    chrome.notifications.create("sapSuccess", {
      type: "basic",
      iconUrl: "icon.png",
      title: "Registro SAP Exitoso",
      message: `Carga rotada exitosamente a ${resData.renamed_to || 'ready'}`,
      priority: 1
    });
  } catch (err) {
    console.error("❌ Error notificando auto-erase:", err);
  }
}

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "GET_STATUS") {
    fetch(`${SERVER_URL}/get-carga`)
      .then(res => res.json())
      .then(data => sendResponse({ connected: true, data }))
      .catch(err => sendResponse({ connected: false, error: err.toString() }));
    return true;
  } else if (request.action === "TRIGGER_CHECK_NOW") {
    sendResponse({ status: "checking" });
    isProcessing = false;
    checkPendingCarga();
    return true;
  } else if (request.action === "SAP_WORKLOG_COMPLETED") {
    sendResponse({ status: "acknowledged" });
    notifyServerComplete().then(() => {
      isProcessing = false;
    });
    return true;
  }
});

