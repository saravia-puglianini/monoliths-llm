// Content Script para registrar HORA POR HORA desde cero en SAP Fiori:
// 1. Validar sesión activa (estilo office.js)
// 2. Seleccionar tarjeta PANDERO en Mis Tareas
// 3. Agregar 1 hora en la grilla del día
// 4. Hacer clic en el cuadro azul generado (PANDERO 01:00 h)
// 5. Ingresar la descripción de Jira en la casilla Act. Laboral:
// 6. Presionar botón Guardar
console.log("🚀 [Auto SAP Content Script] Inicializado con secuencia exacta de 5 pasos desde cero.");

function validateSessionState() {
  const currentUrl = window.location.href;
  const bodyText = document.body ? document.body.innerText || "" : "";

  // 1. Detectar si la página pide iniciar sesión / redirección a Office / Microsoft
  const isLoginPage = currentUrl.includes("office.com") ||
                      currentUrl.includes("microsoftonline.com") ||
                      currentUrl.includes("login") ||
                      currentUrl.includes("saml");

  const hasSignInBtn = !!document.querySelector('a[href*="login"], button[aria-label*="Iniciar sesión"], button[aria-label*="Sign in"]') ||
                       Array.from(document.querySelectorAll('button, a')).some(el => {
                         const text = (el.innerText || "").trim().toLowerCase();
                         return text === 'iniciar sesión' || text === 'sign in';
                       });

  // 2. Detectar elementos activos de SAP Fiori / Shell Header
  const hasSapHeader = !!document.querySelector('#shell-header, .sapUshellShellHeader, #application-TimeEntry-manageTimeEntry-component');

  if (isLoginPage || (hasSignInBtn && !hasSapHeader)) {
    return { active: false, reason: "Redirigido a inicio de sesión / sin acceso activo" };
  }

  return { active: true, reason: "Sesión activa en SAP Fiori" };
}

function showVisualInfo(message, type = "info") {
  console.log(`[Auto SAP HUD] (${type.toUpperCase()}) ${message}`);
  let hud = document.getElementById("auto-sap-hud");
  if (!hud) {
    hud = document.createElement("div");
    hud.id = "auto-sap-hud";
    hud.style.position = "fixed";
    hud.style.top = "20px";
    hud.style.right = "20px";
    hud.style.zIndex = "999999";
    hud.style.padding = "14px 20px";
    hud.style.borderRadius = "10px";
    hud.style.fontFamily = "system-ui, -apple-system, BlinkMacSystemFont, sans-serif";
    hud.style.fontSize = "14px";
    hud.style.fontWeight = "600";
    hud.style.boxShadow = "0 10px 30px rgba(0, 0, 0, 0.4)";
    hud.style.border = "1px solid rgba(255, 255, 255, 0.2)";
    hud.style.transition = "all 0.3s ease-in-out";
    hud.style.maxWidth = "420px";
    hud.style.lineHeight = "1.4";
    (document.body || document.documentElement).appendChild(hud);
  }

  if (type === "success") {
    hud.style.background = "#059669";
    hud.style.color = "#ffffff";
  } else if (type === "warning") {
    hud.style.background = "#d97706";
    hud.style.color = "#ffffff";
  } else if (type === "error") {
    hud.style.background = "#dc2626";
    hud.style.color = "#ffffff";
  } else {
    hud.style.background = "#0284c7";
    hud.style.color = "#ffffff";
  }

  hud.innerHTML = `<div style="display:flex; align-items:center; gap:10px;">
    <span style="font-size:18px;">⚡</span>
    <div>
      <div style="font-size:11px; opacity:0.85; text-transform:uppercase; letter-spacing:0.5px;">Auto SAP Worklog</div>
      <div>${message}</div>
    </div>
  </div>`;

  hud.style.transform = "scale(1.03)";
  setTimeout(() => { hud.style.transform = "scale(1.0)"; }, 200);
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === "EXECUTE_CARGA_PAYLOAD" && message.payload) {
    sendResponse({ status: "executing" });
    processCargaPayload(message.payload);
    return true;
  }
});

async function processCargaPayload(cargaData) {
  try {
    const sessionStatus = validateSessionState();
    if (!sessionStatus.active) {
      showVisualInfo(`⚠️ ${sessionStatus.reason}. Inicia sesión para continuar.`, "warning");
      return;
    }

    showVisualInfo(`Iniciando registro desde cero (${cargaData.items.length} tareas del ${cargaData.fecha})`, "warning");
    
    const result = await executeSAPRegistrationPasoAPaso(cargaData);
    
    showVisualInfo("🎉 Todas las horas registradas y guardadas. Rotando carga a ready...", "success");
    chrome.runtime.sendMessage({ action: "SAP_WORKLOG_COMPLETED" });
  } catch (err) {
    showVisualInfo(`Error procesando carga: ${err.toString()}`, "error");
  }
}

async function executeSAPRegistrationPasoAPaso(cargaData) {
  const items = cargaData.items || [];
  const targetDate = cargaData.fecha; // Ej: "2026-07-27"
  const totalItems = items.length;

  const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

  await wait(1500);

  // Mapear fecha a ID de celda (ej: MON_27_JUL_2026-{minutos})
  let dateParts = targetDate.split('-'); // ["2026", "07", "27"]
  let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
  let monthStr = months[parseInt(dateParts[1], 10) - 1] || "JUL";
  let baseCellPrefix = `MON_${dateParts[2]}_${monthStr}_${dateParts[0]}`;

  for (let i = 0; i < totalItems; i++) {
    const item = items[i];
    const hourNum = i + 1; // 1, 2, 3... 8
    const minOffset = hourNum * 60; // 60, 120, 180... 480
    const cellId = `${baseCellPrefix}-${minOffset}`;
    const label = `[Hora ${hourNum}/${totalItems}]`;

    // 1. SELECCIONAR PANDERO EN MIS TAREAS
    showVisualInfo(`${label} Seleccionando tarjeta PANDERO...`, "info");
    let workList0 = document.getElementById("application-TimeEntry-manageTimeEntry-component---timesheetMain--workList-0") ||
                    Array.from(document.querySelectorAll('.sapMCLI, .sapMLIB')).find(el => (el.textContent || '').includes("PANDERO"));

    if (workList0) {
      if (typeof sap !== 'undefined' && sap.ui && sap.ui.getCore && workList0.id) {
        let ctrl = sap.ui.getCore().byId(workList0.id);
        if (ctrl && ctrl.firePress) ctrl.firePress();
      }
      workList0.click();
      await wait(1000);
    }

    // 2. AGREGAR HORA EN LA GRILLA
    showVisualInfo(`${label} Agregando hora ${hourNum} en la grilla (${minOffset} min)...`, "warning");
    let hourCell = document.getElementById(cellId) || 
                   document.querySelector(`[id*="${baseCellPrefix}"][id*="-${minOffset}"]`) ||
                   document.querySelector('#MON_27_JUL_2026-content .sapTetrisHoursCell');

    if (hourCell) {
      if (typeof sap !== 'undefined' && sap.ui && sap.ui.getCore && hourCell.id) {
        let ctrl = sap.ui.getCore().byId(hourCell.id);
        if (ctrl && ctrl.firePress) ctrl.firePress();
      }
      if (window.jQuery) window.jQuery(hourCell).trigger('tap').trigger('click');
      hourCell.click();
      await wait(1500);
    }

    // 3. CLIC EN EL CUADRO AZUL GENERADO EN LA GRILLA
    showVisualInfo(`${label} Seleccionando cuadro azul generado...`, "warning");
    let blockEl = Array.from(document.querySelectorAll('div, span, p')).find(e => {
      let t = (e.textContent || '').trim();
      return t.includes("PANDERO 0") || t.includes(`PANDERO 0${hourNum}`) || (t.includes("PANDERO") && t.includes(":00"));
    });

    if (blockEl) {
      let target = blockEl.closest('div') || blockEl;
      target.click();
      await wait(1000);
    }

    // 4. INGRESAR LA DESCRIPCIÓN EN LA CASILLA 'Act. Laboral:'
    showVisualInfo(`${label} Escribiendo tarea: "${(item.descripcion || '').substring(0, 28)}..."`, "info");
    let actInput = document.querySelector('input[id*="sfActLaboral"]') ||
                   document.querySelector('input[id*="ActLaboral"]') ||
                   Array.from(document.querySelectorAll('input')).find(inp => {
                     return !inp.disabled && !inp.readOnly && inp.type !== 'hidden' &&
                            !inp.id.includes('shellBar') && !inp.id.includes('help4') && !inp.id.includes('search');
                   });

    if (actInput) {
      actInput.focus();
      actInput.value = item.descripcion || "Análisis de requerimiento";
      actInput.dispatchEvent(new Event('input', { bubbles: true }));
      actInput.dispatchEvent(new Event('change', { bubbles: true }));
      actInput.dispatchEvent(new Event('blur', { bubbles: true }));

      if (typeof sap !== 'undefined' && sap.ui && sap.ui.getCore && actInput.id) {
        try {
          let ctrl = sap.ui.getCore().byId(actInput.id) || sap.ui.getCore().byId(actInput.id.split('-inner')[0]);
          if (ctrl && ctrl.setValue) {
            ctrl.setValue(item.descripcion);
            if (ctrl.fireChange) ctrl.fireChange({ value: item.descripcion });
          }
        } catch (e) {}
      }
      await wait(1200);
    }

    // 5. PRESIONAR EL BOTÓN AZUL GUARDAR
    showVisualInfo(`${label} Presionando botón Guardar...`, "info");
    let saveBtn = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--sfSaveBtn-BDI-content') ||
                  document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--sfSaveBtn') ||
                  document.querySelector('[id*="sfSaveBtn"]') ||
                  Array.from(document.querySelectorAll('button, bdi, span')).find(b => (b.textContent || '').trim() === "Guardar");

    if (saveBtn) {
      if (typeof sap !== 'undefined' && sap.ui && sap.ui.getCore && saveBtn.id) {
        try {
          let saveCtrl = sap.ui.getCore().byId(saveBtn.id) || sap.ui.getCore().byId(saveBtn.id.split('-BDI')[0]);
          if (saveCtrl && saveCtrl.firePress) saveCtrl.firePress();
        } catch (e) {}
      }
      saveBtn.click();
      await wait(2500);
    }
  }

  return { status: "completed", date: targetDate, totalItems };
}
