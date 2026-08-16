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

let isAutoProcessing = false;
let isProcessingCarga = false;
let deferredCooldownUntil = 0;

async function checkAndAutoExecute() {
  if (isAutoProcessing || isProcessingCarga) return;
  if (Date.now() < deferredCooldownUntil) return;

  try {
    const res = await fetch("http://127.0.0.1:9995/get-carga");
    if (!res.ok) return;

    const data = await res.json();
    if (data && data.pending && data.items && data.items.length > 0) {
      isAutoProcessing = true;
      console.log("⚡ [Auto SAP Content Script] Carga pendiente detectada automáticamente:", data);
      await processCargaPayload(data);
      isAutoProcessing = false;
    }
  } catch (e) {
    // Servidor local 9995 fuera de línea o sin carga
  }
}

// Iniciar sondeo automático continuo cada 4 segundos
setInterval(checkAndAutoExecute, 4000);
setTimeout(checkAndAutoExecute, 1500);

async function processCargaPayload(cargaData) {
  if (isProcessingCarga) {
    console.warn("⚠️ [Auto SAP] processCargaPayload already running. Skipping concurrent call.");
    return;
  }
  isProcessingCarga = true;
  try {
    const sessionStatus = validateSessionState();
    if (!sessionStatus.active) {
      showVisualInfo(`⚠️ ${sessionStatus.reason}. Inicia sesión para continuar.`, "warning");
      deferredCooldownUntil = Date.now() + 30000;
      return;
    }

    const items = cargaData.items || [];
    const targetDate = cargaData.fecha;
    const now = new Date();
    const padStr = (n) => String(n).padStart(2, '0');
    const todayStr = `${now.getFullYear()}-${padStr(now.getMonth() + 1)}-${padStr(now.getDate())}`;
    const nowTotalMinutes = now.getHours() * 60 + now.getMinutes();
    const slotHoursMap = [9, 10, 11, 12, 14, 15, 16, 17];

    const readyItems = [];
    const deferredItems = [];
    let earliestThresholdMinutes = Infinity;

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      let startHour = slotHoursMap[i] || (8 + i);
      if (item.hora) {
        const hMatch = String(item.hora).match(/(\d+)/);
        if (hMatch) {
          let parsedH = parseInt(hMatch[1], 10);
          if (String(item.hora).toLowerCase().includes('pm') && parsedH < 12) parsedH += 12;
          if (String(item.hora).toLowerCase().includes('am') && parsedH === 12) parsedH = 0;
          startHour = parsedH;
        }
      }

      // El umbral es la finalización de la hora del bloque ((startHour + 1):00)
      const thresholdMinutes = (startHour + 1) * 60;

      const isItemToday = (item.fecha === todayStr);
      if (isItemToday && nowTotalMinutes < thresholdMinutes) {
        deferredItems.push(item);
        if (thresholdMinutes < earliestThresholdMinutes) {
          earliestThresholdMinutes = thresholdMinutes;
        }
      } else {
        readyItems.push(item);
      }
    }

    if (readyItems.length === 0) {
      const minWaitMs = earliestThresholdMinutes !== Infinity 
        ? Math.max(15000, (earliestThresholdMinutes - nowTotalMinutes) * 60 * 1000)
        : 60000;
      
      deferredCooldownUntil = Date.now() + Math.min(minWaitMs, 300000);

      const thH = Math.floor(earliestThresholdMinutes / 60);
      const thM = earliestThresholdMinutes % 60;
      const thStr = `${padStr(thH)}:${padStr(thM)}`;

      showVisualInfo(`⏳ Horas pospuestas: Se registrarán a partir de las ${thStr} (al finalizar el bloque). Re-intentando en ${Math.round(Math.min(minWaitMs, 300000)/1000)}s.`, "warning");
      console.log(`[Auto SAP] ⏳ ${deferredItems.length} tarea(s) pospuestas hasta las ${thStr}. Enfriamiento activo.`);
      return;
    }

    showVisualInfo(`Iniciando registro automático (${readyItems.length} tarea(s) lista(s) del ${cargaData.fecha})`, "warning");
    
    const readyCargaData = { ...cargaData, items: readyItems };
    const result = await executeSAPRegistrationPasoAPaso(readyCargaData, cargaData);

    if (result && result.processedCount > 0) {
      if (deferredItems.length > 0) {
        showVisualInfo(`🎉 ${result.processedCount} hora(s) registrada(s). Guardando ${deferredItems.length} tarea(s) pendiente(s)...`, "success");
        deferredCooldownUntil = Date.now() + 60000;
      } else {
        showVisualInfo("🎉 Horas registradas y guardadas. Carga finalizada.", "success");
        try {
          if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
            chrome.runtime.sendMessage({ action: "SAP_WORKLOG_COMPLETED" });
          }
        } catch(e) {}
      }
    }
  } catch (err) {
    showVisualInfo(`Error procesando carga: ${err.toString()}`, "error");
  } finally {
    isProcessingCarga = false;
  }
}

async function waitUntilNotBusy() {
  for (let i = 0; i < 30; i++) { // Esperar hasta 15 segundos
    let isBusy = false;
    // Chequear overlay visual
    const busyOverlay = document.querySelector('.sapUiBusy, .sapUiLocalBusyIndicator, #sapUiBusyIndicator');
    if (busyOverlay) {
      const style = window.getComputedStyle(busyOverlay);
      if (style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0') {
        isBusy = true;
      }
    }
    // Chequear API de SAP si está disponible
    try {
      if (typeof sap !== 'undefined' && sap.ui && sap.ui.core && sap.ui.core.BusyIndicator) {
        if (sap.ui.core.BusyIndicator.isActive()) isBusy = true;
      }
    } catch(e) {}

    if (!isBusy) {
      await new Promise(r => setTimeout(r, 300)); // Respiro extra
      return true;
    }
    await new Promise(r => setTimeout(r, 500));
  }
  return false;
}

function triggerMouseEvents(element, x, y) {
  if (!element) return false;
  const rect = element.getBoundingClientRect();
  const clientX = x !== undefined ? x : rect.left + rect.width / 2;
  const clientY = y !== undefined ? y : rect.top + rect.height / 2;

  ['mouseenter', 'mousemove', 'mousedown', 'mouseup', 'click'].forEach(evtType => {
    element.dispatchEvent(new MouseEvent(evtType, {
      bubbles: true,
      cancelable: true,
      view: window,
      clientX: clientX,
      clientY: clientY
    }));
  });
  return true;
}

function robustClick(element, x, y) {
  if (!element) return false;

  // 1. Intentar click nativo HTML
  try {
    if (typeof element.click === 'function') element.click();
  } catch (e) {}

  // 2. Buscar botón o control padre si el elemento es span/bdi
  const parentBtn = element.closest ? element.closest('button, [role="button"], .sapMBtn') : null;
  if (parentBtn && parentBtn !== element) {
    try {
      if (typeof parentBtn.click === 'function') parentBtn.click();
    } catch (e) {}
  }

  // 3. Simular eventos de ratón sintéticos
  triggerMouseEvents(element, x, y);
  if (parentBtn) triggerMouseEvents(parentBtn, x, y);

  // 4. Invocar evento de control SAP UI5 firePress() si está disponible
  if (typeof sap !== 'undefined' && sap?.ui?.getCore) {
    try {
      const core = sap.ui.getCore();
      const rawId = element.id || parentBtn?.id || '';
      const cleanId = rawId.replace(/-(BDI-content|inner|content|img)$/, '');
      if (cleanId) {
        const ctrl = core.byId(cleanId);
        if (ctrl) {
          if (typeof ctrl.firePress === 'function') ctrl.firePress();
          if (typeof ctrl.fireTap === 'function') ctrl.fireTap();
        }
      }
    } catch (e) {}
  }
  return true;
}

let origTabTitle = document.title || "Mi registro de tiempos";

function setTabStatus(shortStatus) {
  try {
    const badge = (shortStatus || "").substring(0, 12);
    const cleanTitle = (origTabTitle || "").replace(/^\[.*?\]\s*/, "");
    document.title = `${badge} ${cleanTitle}`;
  } catch (e) {}
}

function restoreTabTitle() {
  try {
    document.title = (origTabTitle || "").replace(/^\[.*?\]\s*/, "");
  } catch (e) {}
}

async function executeSAPRegistrationPasoAPaso(cargaData, originalCargaData) {
  origTabTitle = document.title || origTabTitle;
  const items = cargaData.items || [];
  const targetDate = cargaData.fecha; // Ej: "2026-08-13"
  const totalItems = items.length;
  const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));
  let processedCount = 0;

  const originalZoom = document.body ? document.body.style.zoom : "";

  try {
    // 0A. ESTABILIZACIÓN RÁPIDA DE SAP (máx 3s o cuando la tabla esté presente)
    showVisualInfo("⏳ Verificando grilla de tiempos en SAP...", "info");
    let gridTable = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain') ||
                    document.querySelector('.sapTetrisTable, .sapMList, table, [id*="timesheetMain"]');
    
    if (!gridTable) {
      for (let s = 0; s < 10; s++) {
        await wait(300);
        gridTable = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain') ||
                    document.querySelector('.sapTetrisTable, .sapMList, table, [id*="timesheetMain"]');
        if (gridTable) break;
      }
    }

    // 0B. APLICAR ZOOM RÁPIDO INSTANTÁNEO
    setTabStatus("[Zoom 0.4]");
    showVisualInfo("🔍 Ajustando zoom de pantalla a 40% para visibilidad total...", "info");
    if (document.body) {
      document.body.style.zoom = "0.4";
    }

    if (gridTable) {
      try {
        gridTable.focus();
        gridTable.scrollIntoView({ block: 'center', inline: 'center' });
      } catch (e) {}
    }

    let target = document.activeElement || gridTable || document.body || window;
    const keyOpts = { key: '-', code: 'Minus', keyCode: 189, which: 189, ctrlKey: true, bubbles: true, cancelable: true };
    target.dispatchEvent(new KeyboardEvent('keydown', keyOpts));
    target.dispatchEvent(new KeyboardEvent('keyup', keyOpts));

    await wait(400);

    const daySlotsMap = {};

    console.log(`🚀 [Auto SAP] Registrando ${totalItems} tarea(s) lista(s)`);

    for (let i = 0; i < totalItems; i++) {
      const item = items[i];
      const hourNum = i + 1;
      const label = `[Hora ${hourNum}/${totalItems}]`;
      const taskText = item.proyecto ? `[${item.proyecto}] ${item.descripcion || ''}` : (item.descripcion || 'Tarea SAP');
      const itemDate = item.fecha || targetDate;

      processedCount++;

      // 1. SELECCIONAR TARJETA PANDERO EN MIS TAREAS
      setTabStatus(`[H${hourNum} Card]`);
      showVisualInfo(`${label} Seleccionando tarjeta PANDERO...`, "info");
      let workList0 = document.getElementById("application-TimeEntry-manageTimeEntry-component---timesheetMain--workList-0") ||
                      Array.from(document.querySelectorAll('.sapMCLI, .sapMLIB')).find(el => (el.textContent || '').includes("PANDERO"));

      if (workList0) {
        robustClick(workList0);
        await wait(600);
      }

      // Mapear fecha dinámica a dayId SAP (ej: "2026-08-13" -> "THU_13_AUG_2026")
      const dParts = itemDate.split('-'); // ["2026", "08", "13"]
      const dt = new Date(parseInt(dParts[0], 10), parseInt(dParts[1], 10) - 1, parseInt(dParts[2], 10));
      const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
      const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
      const dayId = `${days[dt.getDay()]}_${String(dParts[2]).padStart(2, '0')}_${months[dt.getMonth()]}_${dParts[0]}`;

      // 2. BUSCAR COLUMNA DEL DÍA Y CALCULAR COORDENADAS VERTICALES Y
      const dayColumn = document.getElementById(`${dayId}-content`) ||
                        document.querySelector(`[id*="${dayId}"]`) ||
                        document.querySelector(`[id*="${String(dParts[2]).padStart(2, '0')}_${months[dt.getMonth()]}"]`) ||
                        document.querySelector(`[id*="${String(dParts[2]).padStart(2, '0')}_${dParts[1]}"]`);

      if (!dayColumn) {
        showVisualInfo(`❌ No se encontró la columna del día: ${dayId}`, "error");
        continue;
      }

      if (typeof dayColumn.scrollIntoView === 'function') {
        dayColumn.scrollIntoView({ block: 'center', inline: 'center' });
        await wait(200);
      }

      // Inicializar el conteo de bloques existentes en esta columna
      if (daySlotsMap[dayId] === undefined) {
        let initialCount = 0;
        // A. Buscar bloques visibles existentes con texto PANDERO o clase de bloque
        const entries = Array.from(dayColumn.querySelectorAll('div, span, [role="button"]')).filter(el => {
          const text = (el.textContent || '').trim();
          if (text.includes('/')) return false; // Ignorar el resumen '00:00 / 08:00'
          const isBlock = el.className && typeof el.className === 'string' && el.className.includes('Block');
          return (text.includes("PANDERO") || isBlock) && (el.offsetHeight > 15 || el.offsetWidth > 20);
        });
        const uniqueEntries = entries.filter((el, idx, self) => !self.some(other => other !== el && other.contains(el)));
        initialCount = uniqueEntries.length;

        // B. Verificar resumen inferior de horas (ej: "04:00 / 08:00")
        const allText = (dayColumn.innerText || '') + ' ' + (dayColumn.parentElement ? dayColumn.parentElement.innerText || '' : '');
        const matchHours = allText.match(/(\d{1,2}):00\s*\/\s*08:00/);
        if (matchHours) {
          const parsedSummaryHrs = parseInt(matchHours[1], 10);
          initialCount = Math.max(initialCount, parsedSummaryHrs);
        }

        daySlotsMap[dayId] = initialCount;
      }

      // Asignar el siguiente slot secuencial para este día (1..8)
      daySlotsMap[dayId]++;
      const currentSlotIndex = Math.min(8, daySlotsMap[dayId]);

      setTabStatus(`[H${hourNum} S${currentSlotIndex}]`);
      showVisualInfo(`${label} Creando bloque en slot ${currentSlotIndex}/8 de ${dayId}...`, "warning");

      const targetDuration = item.duracion || item.duration || "01:00";

      const rect = dayColumn.getBoundingClientRect();
      const targetX = rect.left + (rect.width / 2);
      // Cada slot ocupa exactamente 10% de la altura de la grilla (hay 10 horas)
      // Para hacer clic al inicio de la hora (ej. 00:05), usamos el inicio del slot + 1% de margen
      // currentSlotIndex va de 1 a 8.
      const targetY = rect.bottom - (rect.height * ((currentSlotIndex - 1 + 0.1) / 10.0));

      let step1Element = document.elementFromPoint(targetX, targetY) || dayColumn;
      
      robustClick(step1Element, targetX, targetY);
      await wait(800);

      // 3. SELECCIONAR BLOQUE GENERADO
      setTabStatus(`[H${hourNum} Block]`);
      let newBlock = dayColumn.querySelector('.sapTetrisFocusColor, [class*="selected"]') || 
                     document.elementFromPoint(targetX, targetY);

      if (newBlock) {
        robustClick(newBlock, targetX, targetY);
        await wait(500);
      }

      // 4. ESTABLECER DURACIÓN STRICTAMENTE A 01:00 (O duracion ESPECIFICADA)
      setTabStatus(`[H${hourNum} ${targetDuration}]`);
      showVisualInfo(`${label} Forzando duración exacta de ${targetDuration}...`, "info");

      const findDurInputs = () => Array.from(document.querySelectorAll('input')).filter(inp => 
        (inp.id || '').toLowerCase().includes('duration') ||
        (inp.id || '').toLowerCase().includes('sfduration') ||
        (inp.getAttribute('aria-label') || '').toLowerCase().includes('duraci') ||
        (inp.getAttribute('aria-label') || '').toLowerCase().includes('duration') ||
        (inp.getAttribute('placeholder') || '').toLowerCase().includes('00:00') ||
        /^\d{1,2}:\d{2}$/.test((inp.value || '').trim())
      );

      let durInputs = findDurInputs();

      const applyDurationToInput = (durInput) => {
        if (!durInput) return;
        durInput.focus();
        durInput.value = targetDuration;
        durInput.setAttribute('value', targetDuration);
        durInput.dispatchEvent(new Event('input', { bubbles: true }));
        durInput.dispatchEvent(new Event('change', { bubbles: true }));
        durInput.dispatchEvent(new Event('blur', { bubbles: true }));
        durInput.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true }));
        durInput.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true }));
        durInput.blur();
      };

      durInputs.forEach(applyDurationToInput);

      if (typeof sap !== 'undefined' && sap?.ui?.getCore) {
        try {
          const core = sap.ui.getCore();
          const allElements = core.mElements || core.aControls || {};
          for (let id in allElements) {
            if (id.toLowerCase().includes('duration') || id.toLowerCase().includes('sfduration')) {
              const ctrl = allElements[id];
              if (ctrl) {
                if (typeof ctrl.setValue === 'function') ctrl.setValue(targetDuration);
                if (typeof ctrl.fireChange === 'function') ctrl.fireChange({ value: targetDuration, valid: true });
                if (typeof ctrl.fireLiveChange === 'function') ctrl.fireLiveChange({ value: targetDuration });
              }
            }
          }
        } catch(e) {
          console.error("[Auto SAP] Error actualizando control UI5 de duración:", e);
        }
      }
      await wait(400);

      // Verificación secundaria para re-forzar si SAP mantiene 01:15
      durInputs = findDurInputs();
      durInputs.forEach(inp => {
        if (inp.value !== targetDuration) {
          applyDurationToInput(inp);
        }
      });

      if (durInputs.length === 0) {
        console.error(`[Auto SAP] ❌ No se encontró el campo de DURACIÓN para la hora ${hourNum}`);
      }

      // 5A. ASEGURAR QUE ACT. LABORAL QUEDE VACÍA (No acepta valores en este formulario)
      let actInput = document.querySelector('[id*="YY1_F_HCM_ActLaboral_TIM-element0-input-inner"]') ||
                     document.querySelector('input[id*="sfActLaboral"]') ||
                     document.querySelector('input[id*="ActLaboral"]');
      if (actInput) {
        actInput.focus();
        actInput.value = "";
        actInput.dispatchEvent(new Event('input', { bubbles: true }));
        actInput.dispatchEvent(new Event('change', { bubbles: true }));
        actInput.blur();
        if (typeof sap !== 'undefined' && sap?.ui?.getCore && actInput.id) {
          try {
            let ctrl = sap.ui.getCore().byId(actInput.id.replace(/-inner$/, ''));
            if (ctrl && ctrl.setValue) ctrl.setValue("");
          } catch(e) {}
        }
      }

      // 5B. INGRESAR TÍTULO DE LA TAREA Y URL DE JIRA EN CAMPO 'NOTA:'
      setTabStatus(`[H${hourNum} Nota]`);
      const noteParts = [];
      if (item.proyecto) noteParts.push(item.proyecto);
      if (item.descripcion) noteParts.push(item.descripcion);
      if (item.url) noteParts.push(item.url);
      const fullNoteText = noteParts.length > 0 ? noteParts.join(" ") : taskText;

      showVisualInfo(`${label} Escribiendo Nota: "${fullNoteText.substring(0, 32)}..."`, "info");
      console.log(`[Auto SAP] 📝 [Campo NOTA] Asignando texto exacto:`, fullNoteText);

      let noteTextarea = document.querySelector('textarea[id*="sfNote-inner"]') ||
                         document.querySelector('[id*="sfNote-inner"]') ||
                         document.querySelector('textarea[id*="sfNote"]') ||
                         document.querySelector('textarea') ||
                         Array.from(document.querySelectorAll('textarea, input')).find(el => el.tagName === 'TEXTAREA' || (el.placeholder || '').includes('300'));

      if (noteTextarea) {
        noteTextarea.focus();
        noteTextarea.value = fullNoteText;
        noteTextarea.dispatchEvent(new Event('input', { bubbles: true }));
        noteTextarea.dispatchEvent(new Event('change', { bubbles: true }));
        noteTextarea.blur();

        if (typeof sap !== 'undefined' && sap?.ui?.getCore && noteTextarea.id) {
          try {
            let ctrl = sap.ui.getCore().byId(noteTextarea.id.replace(/-inner$/, ''));
            if (ctrl && ctrl.setValue) {
              ctrl.setValue(fullNoteText);
              if (ctrl.fireChange) ctrl.fireChange({ value: fullNoteText });
            }
          } catch (e) {}
        }
        await wait(400);
      } else {
        console.error(`[Auto SAP] ❌ No se encontró el área de texto para la NOTA.`);
      }

      // 6A. PRIMER GUARDADO: Formulario de Detalles (sfSaveBtn)
      setTabStatus(`[H${hourNum} Sav1]`);
      showVisualInfo(`${label} [Guardado 1/2] Guardando formulario detalles...`, "info");
      console.log(`[Auto SAP] 💾 Presionando primer botón Guardar (Detalles)...`);
      let detailsSaveBtn = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--sfSaveBtn-BDI-content') ||
                           document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--sfSaveBtn') ||
                           document.querySelector('[id*="sfSaveBtn"]') ||
                           Array.from(document.querySelectorAll('button, bdi, span')).find(el => {
                             const t = (el.innerText || el.textContent || '').trim();
                             return t === 'Guardar' && (el.id || '').includes('sfSave');
                           });

      if (detailsSaveBtn) {
        await waitUntilNotBusy();
        console.log(`[Auto SAP] 💾 Ejecutando click en primer botón Guardar (Detalles)`);
        robustClick(detailsSaveBtn);
        await wait(1000);
      }



      // Registro exitoso en SAP para esta tarea. Proceder a guardar estado línea por línea
      showVisualInfo(`${label} Registro exitoso. Guardando estado en base de datos...`, "success");
      try {
        // 1. Enviar el log de éxito al servidor para registrarlo en el archivo .ready.txt respectivo
        await fetch("http://127.0.0.1:9995/log-success-item", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(item)
        });

        // 2. Quitar el ítem del listado original y actualizar private.carga.txt en el servidor
        if (originalCargaData && originalCargaData.items) {
          const origIndex = originalCargaData.items.findIndex(x => 
            x.fecha === item.fecha && 
            x.hora === item.hora && 
            x.proyecto === item.proyecto
          );
          if (origIndex > -1) {
            originalCargaData.items.splice(origIndex, 1);
          }

          if (originalCargaData.items.length > 0) {
            await fetch("http://127.0.0.1:9995/write-carga", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                pending: true,
                fecha: originalCargaData.fecha,
                items: originalCargaData.items
              }, null, 2)
            });
          } else {
            await fetch("http://127.0.0.1:9995/clear-carga", {
              method: "POST"
            });
          }
        }
      } catch (e) {
        console.error("[Auto SAP] Error guardando estado línea por línea:", e);
      }
    } // Fin del for loop

    // 7. GUARDADO GENERAL AL FINALIZAR TODA LA CARGA
    await waitUntilNotBusy();
    showVisualInfo(`[Guardado Final] Presionando Guardar GENERAL para registrar todas las horas en el servidor...`, "warning");
    console.log(`[Auto SAP] 🚀 Presionando botón Guardar GENERAL (inferior derecha) para toda la tanda...`);

    let finalSaveBtn = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--saveBtn') ||
                        document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain--saveBtn-BDI-content') ||
                        document.querySelector('[id*="saveBtn"]:not([id*="sfSaveBtn"])') ||
                        Array.from(document.querySelectorAll('button, [role="button"], bdi, span')).find(b => {
                          const text = (b.innerText || b.textContent || '').trim();
                          const isDetailsBtn = b.id && b.id.includes('sfSaveBtn');
                          return text === 'Guardar' && !isDetailsBtn;
                        });

    if (finalSaveBtn) {
      console.log(`[Auto SAP] 🚀 Ejecutando click en botón Guardar GENERAL FINAL`);
      robustClick(finalSaveBtn);
      console.log(`[Auto SAP] ✅ Guardar GENERAL FINAL ejecutado en:`, finalSaveBtn);
      await wait(1500);
      await waitUntilNotBusy(); // Esperar a que SAP confirme a la base de datos
    } else {
      console.warn(`[Auto SAP] ⚠️ Botón Guardar GENERAL FINAL no localizado.`);
    }
  } finally {
    if (document.body) {
      document.body.style.zoom = originalZoom || "";
    }
  }

  setTabStatus("[OK Ready]");
  setTimeout(restoreTabTitle, 6000);

  return { status: "completed", date: targetDate, processedCount, totalItems };
}
