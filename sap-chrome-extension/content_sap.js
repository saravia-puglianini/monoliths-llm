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

async function checkAndAutoExecute() {
  if (isAutoProcessing) return;

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
  try {
    const sessionStatus = validateSessionState();
    if (!sessionStatus.active) {
      showVisualInfo(`⚠️ ${sessionStatus.reason}. Inicia sesión para continuar.`, "warning");
      return;
    }

    showVisualInfo(`Iniciando registro automático desde cero (${cargaData.items.length} tarea(s) del ${cargaData.fecha})`, "warning");
    
    const result = await executeSAPRegistrationPasoAPaso(cargaData);
    
    showVisualInfo("🎉 Todas las horas registradas y guardadas. Rotando carga a ready...", "success");
    
    // Notificar rotación al servidor local 9995 y al background worker
    try {
      await fetch("http://127.0.0.1:9995/auto-erase-carga");
    } catch (e) {}

    chrome.runtime.sendMessage({ action: "SAP_WORKLOG_COMPLETED" });
  } catch (err) {
    showVisualInfo(`Error procesando carga: ${err.toString()}`, "error");
  }
}

function triggerMouseEvents(element) {
  if (!element) return false;
  const rect = element.getBoundingClientRect();
  const clientX = rect.left + rect.width / 2;
  const clientY = rect.top + rect.height / 2;

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

async function executeSAPRegistrationPasoAPaso(cargaData) {
  origTabTitle = document.title || origTabTitle;
  const items = cargaData.items || [];
  const targetDate = cargaData.fecha; // Ej: "2026-08-13"
  const totalItems = items.length;
  const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

  // 0A. ESPERAR 15 SEGUNDOS DE ESTABILIZACIÓN CON CUENTA REGRESIVA EN TAB TITLE ([Wait 15s])
  showVisualInfo("⏳ Esperando 15s para estabilización de dominios en SAP...", "warning");
  console.log("%c[Auto SAP] ⏳ Esperando 15 segundos de estabilización previa...", "color: #d97706; font-weight: bold; font-size: 14px;");

  for (let s = 15; s > 0; s--) {
    setTabStatus(`[Wait ${s}s]`);
    showVisualInfo(`⏳ Esperando estabilización SAP (${s}s restantes)...`, "warning");
    await wait(1000);
  }

  // 0B. APLICAR FOCO A LA TABLA Y 20 VECES CTRL + - (ZOOM OUT CON PAUSA DE 1S)
  showVisualInfo("🔍 Enfocando grilla y ejecutando 20 iteraciones de Ctrl+- (1s de pausa)...", "warning");
  let gridTable = document.querySelector('#application-TimeEntry-manageTimeEntry-component---timesheetMain') ||
                  document.querySelector('.sapTetrisTable, .sapMList, table, [id*="timesheetMain"]');
  
  if (gridTable) {
    try {
      gridTable.focus();
      gridTable.scrollIntoView({ block: 'center', inline: 'center' });
    } catch (e) {}
  }

  for (let z = 1; z <= 20; z++) {
    const zoomBadge = `[Zoom ${z}/20]`;
    setTabStatus(zoomBadge);
    showVisualInfo(`🔍 [Paso ${z}/20] Presionando Ctrl+- (pausa 1s para visibilidad total)...`, "warning");
    let currentZoom = Math.max(0.35, 1.0 - (z * 0.03));
    if (document.body) {
      document.body.style.zoom = `${currentZoom}`;
    }

    let target = document.activeElement || gridTable || document.body || window;
    try { if (target.focus) target.focus(); } catch (e) {}

    const keyOpts1 = { key: '-', code: 'Minus', keyCode: 189, which: 189, ctrlKey: true, bubbles: true, cancelable: true };
    const keyOpts2 = { key: '-', code: 'NumpadSubtract', keyCode: 109, which: 109, ctrlKey: true, bubbles: true, cancelable: true };

    target.dispatchEvent(new KeyboardEvent('keydown', keyOpts1));
    target.dispatchEvent(new KeyboardEvent('keyup', keyOpts1));
    target.dispatchEvent(new KeyboardEvent('keydown', keyOpts2));
    target.dispatchEvent(new KeyboardEvent('keyup', keyOpts2));

    await wait(1000);
  }

  await wait(500);

  // Mapear fecha dinámica a dayId SAP (ej: "2026-08-13" -> "THU_13_AUG_2026")
  const dParts = targetDate.split('-'); // ["2026", "08", "13"]
  const dt = new Date(parseInt(dParts[0], 10), parseInt(dParts[1], 10) - 1, parseInt(dParts[2], 10));
  const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
  const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
  const dayId = `${days[dt.getDay()]}_${String(dParts[2]).padStart(2, '0')}_${months[dt.getMonth()]}_${dParts[0]}`;

  console.log(`🚀 [Auto SAP] Registrando ${totalItems} tareas para el día ID: ${dayId}`);

  for (let i = 0; i < totalItems; i++) {
    const item = items[i];
    const hourNum = i + 1;
    const label = `[Hora ${hourNum}/${totalItems}]`;
    const taskText = item.proyecto ? `[${item.proyecto}] ${item.descripcion || ''}` : (item.descripcion || 'Tarea SAP');

    // 1. SELECCIONAR TARJETA PANDERO EN MIS TAREAS
    setTabStatus(`[H${hourNum} Card]`);
    showVisualInfo(`${label} Seleccionando tarjeta PANDERO...`, "info");
    let workList0 = document.getElementById("application-TimeEntry-manageTimeEntry-component---timesheetMain--workList-0") ||
                    Array.from(document.querySelectorAll('.sapMCLI, .sapMLIB')).find(el => (el.textContent || '').includes("PANDERO"));

    if (workList0) {
      triggerMouseEvents(workList0);
      await wait(600);
    }

    // 2. BUSCAR COLUMNA DEL DÍA Y CALCULAR COORDENADAS VERTICALES Y
    setTabStatus(`[H${hourNum} Grid]`);
    showVisualInfo(`${label} Creando bloque de hora ${hourNum} en ${dayId}...`, "warning");
    const dayColumn = document.getElementById(`${dayId}-content`) || document.querySelector(`[id*="${dayId}"]`);
    if (!dayColumn) {
      showVisualInfo(`❌ No se encontró la columna del día: ${dayId}`, "error");
      continue;
    }

    if (typeof dayColumn.scrollIntoView === 'function') {
      dayColumn.scrollIntoView({ block: 'center', inline: 'center' });
      await wait(200);
    }

    const rect = dayColumn.getBoundingClientRect();
    const targetX = rect.left + (rect.width / 2);
    const targetY = rect.bottom - (rect.height * ((hourNum + 0.2) / 10.5));

    let step1Element = document.elementFromPoint(targetX, targetY) || dayColumn;
    triggerMouseEvents(step1Element);
    await wait(600);

    // 3. SELECCIONAR BLOQUE GENERADO
    setTabStatus(`[H${hourNum} Block]`);
    let newBlock = dayColumn.querySelector('.sapTetrisFocusColor, [class*="selected"]') || 
                   document.elementFromPoint(targetX, targetY);

    if (newBlock) {
      triggerMouseEvents(newBlock);
      await wait(500);
    }

    // 4. ESTABLECER DURACIÓN A 01:00
    setTabStatus(`[H${hourNum} 01:00]`);
    let durInput = Array.from(document.querySelectorAll('input')).find(inp => 
      /^\d{2}:\d{2}$/.test(inp.value) || (inp.id || '').toLowerCase().includes('duration')
    ) || document.querySelector('[id*="sfDuration-inner"], [id*="Duration-inner"]');

    if (durInput) {
      durInput.focus();
      durInput.value = "01:00";
      durInput.dispatchEvent(new Event('input', { bubbles: true }));
      durInput.dispatchEvent(new Event('change', { bubbles: true }));
      durInput.blur();
      if (typeof sap !== 'undefined' && sap?.ui?.getCore) {
        try {
          const ctrl = sap.ui.getCore().byId(durInput.id.replace(/-inner$/, ''));
          if (ctrl && ctrl.setValue) ctrl.setValue("01:00");
        } catch(e) {}
      }
      await wait(300);
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
                         document.querySelector('[id*="sfSaveBtn"]');

    if (detailsSaveBtn) {
      triggerMouseEvents(detailsSaveBtn);
      await wait(1200);
    }

    // 6B. SEGUNDO GUARDADO: Botón GENERAL Inferior Derecho (Barra Azul)
    setTabStatus(`[H${hourNum} Sav2]`);
    showVisualInfo(`${label} [Guardado 2/2] Presionando Guardar GENERAL (inferior derecha)...`, "warning");
    console.log(`[Auto SAP] 🚀 Presionando botón Guardar GENERAL (inferior derecha)...`);

    const allButtons = Array.from(document.querySelectorAll('button, [role="button"], bdi, span'));
    const bottomSaveBtn = allButtons.find(b => {
      const text = (b.innerText || b.textContent || '').trim();
      const isDetailsBtn = b.id && b.id.includes('sfSaveBtn');
      return text === 'Guardar' && !isDetailsBtn;
    }) || document.querySelector('[id*="saveBtn"]:not([id*="sfSaveBtn"]), [id*="footer"] [id*="save"]');

    if (bottomSaveBtn) {
      const targetBtn = bottomSaveBtn.closest('button, [role="button"]') || bottomSaveBtn;
      triggerMouseEvents(targetBtn);
      console.log(`[Auto SAP] ✅ Guardar GENERAL ejecutado en:`, targetBtn);
      await wait(1800);
    } else {
      console.warn(`[Auto SAP] ⚠️ Botón Guardar GENERAL no localizado por filtro secundario.`);
      await wait(1000);
    }
  }

  setTabStatus("[OK Ready]");
  setTimeout(restoreTabTitle, 6000);

  return { status: "completed", date: targetDate, totalItems };
}
