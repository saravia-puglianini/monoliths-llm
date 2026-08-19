// Estado global persistente
window.__whiteoutState = window.__whiteoutState || { video: true, img: true };
window.__micActive = window.__micActive ?? null;
window.__reunionesAbiertas = window.__reunionesAbiertas || new Set();
window.__germanTranslatorActive = window.__germanTranslatorActive ?? true;

(async function () {
    'use strict';

    const url = window.location.href;
    const host = window.location.hostname;

    // ==========================================
    // 1. MÓDULO GLOBAL: BARRA DE CONTROLES BASE
    // ==========================================
    window.__whiteoutState = localStorage.getItem('monkey_whiteout') ? JSON.parse(localStorage.getItem('monkey_whiteout')) : { video: true, img: true };
    window.__germanTranslatorActive = localStorage.getItem('monkey_german') !== null ? localStorage.getItem('monkey_german') === 'true' : true;
    const SERVER_URL = 'http://127.0.0.1:8888';

    let debugServerReachable = true;
    function monkeyDebugLog(tag, msg, data = {}) {
        const payload = {
            timestamp: new Date().toISOString(),
            tag: tag,
            message: msg,
            data: data
        };
        console.log(`[MONKEY-DEBUG] [${tag}] ${msg}`, data);
        try {
            gmFetch('http://127.0.0.1:8888/debug_log', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            }).catch(() => {});
        } catch (e) {}
    }

    function isMonkeyPaused() {
        const pauseUntil = parseInt(localStorage.getItem('monkey_pause_until') || '0', 10);
        return pauseUntil && pauseUntil > Date.now();
    }

    // Sincronizar con chrome.storage (popup del addon)
    function syncStorageWithExtension() {
        window.postMessage({ type: 'GET_MONKEY_STORAGE', id: 'sync_' + Date.now() }, '*');
    }

    window.addEventListener('message', (event) => {
        if (event.source !== window || !event.data) return;
        if (event.data.type === 'FROM_MONKEY_STORAGE_RESPONSE') {
            const { pauseUntil, offHours } = event.data.data || {};
            if (pauseUntil !== undefined) {
                localStorage.setItem('monkey_pause_until', pauseUntil);
            }
            if (offHours !== undefined) {
                localStorage.setItem('monkey_off_hours', offHours);
            }
            if (typeof updateGlobalUI === 'function') {
                updateGlobalUI();
            }
        }
    });

    setInterval(syncStorageWithExtension, 3000);
    syncStorageWithExtension();

    function setExtensionPause(targetTime, offHours) {
        localStorage.setItem('monkey_pause_until', targetTime);
        localStorage.setItem('monkey_off_hours', offHours);
        window.postMessage({
            type: 'SET_MONKEY_STORAGE',
            id: 'set_' + Date.now(),
            data: { pauseUntil: targetTime, offHours: offHours }
        }, '*');
    }

    async function gmFetch(url, options = {}) {
        return new Promise((resolve, reject) => {
            const id = Date.now() + '_' + Math.random().toString();
            const listener = (event) => {
                if (event.source !== window) return;
                if (event.data && event.data.type === 'FROM_CONTENT_FETCH_RESPONSE' && event.data.id === id) {
                    window.removeEventListener('message', listener);
                    const res = event.data.response;
                    if (res && res.success) {
                        resolve({
                            ok: res.data.ok,
                            status: res.data.status,
                            json: () => Promise.resolve(JSON.parse(res.data.text)),
                            text: () => Promise.resolve(res.data.text)
                        });
                    } else {
                        reject(new Error(res ? res.error : 'Unknown error'));
                    }
                }
            };
            window.addEventListener('message', listener);
            window.postMessage({ type: 'FROM_PAGE_FETCH', id, url, options: { method: options.method, headers: options.headers, body: options.body } }, '*');
        });
    }

    if (window === window.top) {
        let styleGlobal = document.getElementById('whiteout-dynamic-css');
        if (!styleGlobal) {
            styleGlobal = document.createElement('style');
            styleGlobal.id = 'whiteout-dynamic-css';
            (document.head || document.documentElement).appendChild(styleGlobal);
        }

        styleGlobal.textContent = `
            ${window.__whiteoutState.video ? `
                video, canvas, ytd-shorts-player-view-model video {
                    filter: brightness(0) invert(1) !important;
                    background-color: white !important;
                    opacity: 1 !important;
                    visibility: visible !important;
                }
            ` : ''}
            ${window.__whiteoutState.img ? `
                img, image, .ytp-videowall-still-image, .ytp-cued-thumbnail-overlay-image, [style*="background-image"] {
                    filter: brightness(0) invert(1) !important;
                    background-color: white !important;
                    opacity: 1 !important;
                }
            ` : ''}
        `;

        if (document.body) {
            let container = document.getElementById('control-panel-container');
            if (!container) {
                container = document.createElement('div');
                container.id = 'control-panel-container';
                container.style.cssText = 'position:fixed!important;bottom:25px!important;right:25px!important;z-index:2147483647!important;display:flex!important;gap:10px!important;align-items:center!important;user-select:none!important;';
                document.body.appendChild(container);
            }

            const globalButtons = [
                {
                    id: 'btn-toggle-video',
                    getSymbol: () => '🎬',
                    getTitle: () => `Blanqueo Video: ${window.__whiteoutState.video ? 'ACTIVO (Clic para Mostrar)' : 'DESACTIVADO (Clic para Blanquear)'}`,
                    getBg: () => window.__whiteoutState.video ? '#1565c0' : '#424242',
                    getOpacity: () => window.__whiteoutState.video ? '1' : '0.45',
                    onClick: () => {
                        window.__whiteoutState.video = !window.__whiteoutState.video;
                        localStorage.setItem('monkey_whiteout', JSON.stringify(window.__whiteoutState));
                        updateGlobalUI();
                    }
                },
                {
                    id: 'btn-toggle-img',
                    getSymbol: () => '🖼️',
                    getTitle: () => `Blanqueo Imagen: ${window.__whiteoutState.img ? 'ACTIVO (Clic para Mostrar)' : 'DESACTIVADO (Clic para Blanquear)'}`,
                    getBg: () => window.__whiteoutState.img ? '#6a1b9a' : '#424242',
                    getOpacity: () => window.__whiteoutState.img ? '1' : '0.45',
                    onClick: () => {
                        window.__whiteoutState.img = !window.__whiteoutState.img;
                        localStorage.setItem('monkey_whiteout', JSON.stringify(window.__whiteoutState));
                        updateGlobalUI();
                    }
                },
                {
                    id: 'btn-toggle-mic',
                    getSymbol: () => window.__micActive ? '🎙️' : '🛑',
                    getTitle: () => `Micrófono ALSA: ${window.__micActive ? 'ACTIVO (Clic para Pausar)' : 'PAUSADO (Clic para Reanudar)'}`,
                    getBg: () => window.__micActive ? '#2e7d32' : '#c62828',
                    getOpacity: () => '1',
                    isVisible: () => window.__micActive !== null,
                    onClick: () => controlMic('/toggle')
                },
                {
                    id: 'btn-toggle-translator',
                    getSymbol: () => '🇩🇪',
                    getTitle: () => `Traductor DE->ES: ${window.__germanTranslatorActive ? 'ACTIVO' : 'DESACTIVADO'}`,
                    getBg: () => window.__germanTranslatorActive ? '#fbc02d' : '#424242',
                    getOpacity: () => window.__germanTranslatorActive ? '1' : '0.45',
                    onClick: () => {
                        window.__germanTranslatorActive = !window.__germanTranslatorActive;
                        localStorage.setItem('monkey_german', window.__germanTranslatorActive);
                        updateGlobalUI();
                    }
                },
                {
                    id: 'btn-toggle-periodo-off',
                    getSymbol: () => isMonkeyPaused() ? '⏸️' : '⏱️',
                    getTitle: () => {
                        if (isMonkeyPaused()) {
                            const pUntil = parseInt(localStorage.getItem('monkey_pause_until') || '0', 10);
                            const remMin = Math.round((pUntil - Date.now()) / 60000);
                            return `Periodo OFF ACTIVO (Pausado por ~${remMin}m). Clic para reanudar.`;
                        }
                        const h = localStorage.getItem('monkey_off_hours') || '1';
                        return `Hora en Periodo off... (${h}h). Clic para configurar / pausar.`;
                    },
                    getBg: () => isMonkeyPaused() ? '#d32f2f' : '#0284c7',
                    getOpacity: () => '1',
                    onClick: () => {
                        showPeriodoOffModal();
                    }
                }
            ];

            function showPeriodoOffModal() {
                let existingModal = document.getElementById('monkey-periodo-off-modal');
                if (existingModal) {
                    existingModal.remove();
                    return;
                }

                const backdrop = document.createElement('div');
                backdrop.id = 'monkey-periodo-off-modal';
                backdrop.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;background:rgba(0,0,0,0.5)!important;backdrop-filter:blur(4px)!important;z-index:2147483647!important;display:flex!important;align-items:center!important;justify-content:center!important;font-family:system-ui,-apple-system,sans-serif!important;';

                const card = document.createElement('div');
                card.style.cssText = 'background:#1e293b!important;color:#f8fafc!important;border:1px solid rgba(255,255,255,0.15)!important;border-radius:12px!important;padding:20px!important;width:300px!important;box-shadow:0 20px 40px rgba(0,0,0,0.4)!important;display:flex!important;flex-direction:column!important;gap:14px!important;';

                const titleRow = document.createElement('div');
                titleRow.style.cssText = 'display:flex!important;justify-content:space-between!important;align-items:center!important;';
                const title = document.createElement('div');
                title.style.cssText = 'font-weight:700!important;font-size:15px!important;color:#38bdf8!important;';
                title.textContent = '⏱️ Personal Monkey';
                const closeBtn = document.createElement('button');
                closeBtn.textContent = '✕';
                closeBtn.style.cssText = 'background:none!important;border:none!important;color:#94a3b8!important;font-size:16px!important;cursor:pointer!important;';
                closeBtn.onclick = () => backdrop.remove();
                titleRow.appendChild(title);
                titleRow.appendChild(closeBtn);

                const currentHours = localStorage.getItem('monkey_off_hours') || '1';
                const inputRow = document.createElement('div');
                inputRow.style.cssText = 'display:flex!important;justify-content:space-between!important;align-items:center!important;margin-top:4px!important;';
                const label = document.createElement('span');
                label.style.cssText = 'font-size:13px!important;font-weight:600!important;';
                label.textContent = 'Hora en Periodo off...';
                const numInput = document.createElement('input');
                numInput.type = 'number';
                numInput.min = '0.5';
                numInput.max = '24';
                numInput.step = '0.5';
                numInput.value = currentHours;
                numInput.style.cssText = 'width:60px!important;background:#0f172a!important;color:#f8fafc!important;border:1px solid #475569!important;border-radius:6px!important;padding:5px 8px!important;font-weight:bold!important;text-align:center!important;outline:none!important;';

                inputRow.appendChild(label);
                inputRow.appendChild(numInput);

                const statusText = document.createElement('div');
                statusText.style.cssText = 'font-size:11px!important;text-align:center!important;';
                
                const actionBtn = document.createElement('button');
                actionBtn.style.cssText = 'width:100%!important;padding:9px!important;border:none!important;border-radius:6px!important;font-weight:700!important;font-size:13px!important;cursor:pointer!important;color:#fff!important;transition:all .2s ease!important;';

                function updateModalState() {
                    if (isMonkeyPaused()) {
                        const pUntil = parseInt(localStorage.getItem('monkey_pause_until') || '0', 10);
                        const remMin = Math.round((pUntil - Date.now()) / 60000);
                        const dateStr = new Date(pUntil).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                        statusText.textContent = `Pausado hasta las ${dateStr} (~${remMin}m)`;
                        statusText.style.color = '#f87171';
                        actionBtn.textContent = '▶️ Reanudar Addon';
                        actionBtn.style.background = '#059669';
                    } else {
                        statusText.textContent = 'Estado: Activo';
                        statusText.style.color = '#38bdf8';
                        const h = numInput.value || 1;
                        actionBtn.textContent = `⏸️ Pausar por ${h} hora(s)`;
                        actionBtn.style.background = '#dc2626';
                    }
                }

                numInput.oninput = () => {
                    localStorage.setItem('monkey_off_hours', numInput.value || '1');
                    updateModalState();
                };

                actionBtn.onclick = () => {
                    if (isMonkeyPaused()) {
                        setExtensionPause(0, parseFloat(numInput.value) || 1);
                    } else {
                        const hours = parseFloat(numInput.value) || 1;
                        const targetTime = Date.now() + (hours * 3600 * 1000);
                        setExtensionPause(targetTime, hours);
                    }
                    updateGlobalUI();
                    backdrop.remove();
                };

                updateModalState();

                card.appendChild(titleRow);
                card.appendChild(inputRow);
                card.appendChild(actionBtn);
                card.appendChild(statusText);
                backdrop.appendChild(card);
                backdrop.onclick = (e) => { if (e.target === backdrop) backdrop.remove(); };

                document.body.appendChild(backdrop);
            }

            function updateGlobalUI() {
                if (styleGlobal) {
                    styleGlobal.textContent = `
                        ${window.__whiteoutState.video ? 'video, canvas, ytd-shorts-player-view-model video { filter: brightness(0) invert(1) !important; background-color: white !important; opacity: 1 !important; visibility: visible !important; }' : ''}
                        ${window.__whiteoutState.img ? 'img, image, .ytp-videowall-still-image, .ytp-cued-thumbnail-overlay-image, [style*="background-image"] { filter: brightness(0) invert(1) !important; background-color: white !important; opacity: 1 !important; }' : ''}
                    `;
                }

                globalButtons.forEach(cfg => {
                    let btn = document.getElementById(cfg.id);
                    if (!btn) {
                        btn = document.createElement('div');
                        btn.id = cfg.id;
                        btn.style.cssText = 'width:46px!important;height:46px!important;border-radius:50%!important;display:flex!important;align-items:center!important;justify-content:center!important;font-size:22px!important;cursor:pointer!important;box-shadow:0px 4px 12px rgba(0,0,0,0.4)!important;transition:transform .2s ease,opacity .2s ease!important;';
                        btn.onmouseover = () => btn.style.transform = 'scale(1.1)';
                        btn.onmouseout = () => btn.style.transform = 'scale(1.0)';
                        btn.onclick = (e) => { e.stopPropagation(); cfg.onClick(); };
                        container.appendChild(btn);
                    }

                    if (cfg.isVisible && !cfg.isVisible()) {
                        btn.style.setProperty('display', 'none', 'important');
                    } else {
                        btn.style.setProperty('display', 'flex', 'important');
                        btn.textContent = cfg.getSymbol();
                        btn.title = cfg.getTitle();
                        btn.style.backgroundColor = cfg.getBg();
                        btn.style.opacity = cfg.getOpacity();
                    }
                });
            }

            async function controlMic(endpoint) {
                try {
                    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 1500));
                    const res = await Promise.race([gmFetch(`${SERVER_URL}${endpoint}`), timeoutPromise]);
                    const data = await res.json();
                    window.__micActive = data.active;
                } catch {
                    window.__micActive = null;
                }
                updateGlobalUI();
            }

            updateGlobalUI();
            controlMic('/status').catch(() => {});

            // ==========================================
            // RELOJ GLOBAL (Mismo estilo para todos)
            // ==========================================
            if (!document.getElementById('global-clock-style')) {
                const styleClock = document.createElement('style');
                styleClock.id = 'global-clock-style';
                styleClock.textContent = `
                    #global-clock-panel {
                        position: fixed !important;
                        top: 20px !important;
                        right: 20px !important;
                        background-color: #90ee90 !important;
                        padding: 12px 20px !important;
                        border-radius: 10px !important;
                        box-shadow: 0 4px 15px rgba(0,0,0,0.3) !important;
                        z-index: 2147483647 !important;
                        display: flex !important;
                        flex-direction: column !important;
                        align-items: flex-end !important;
                        border: 2px solid #2e7d32 !important;
                        min-width: 210px !important;
                        font-family: 'Segoe UI', Arial, sans-serif !important;
                        cursor: pointer !important;
                        user-select: none !important;
                        transition: opacity 0.3s ease, transform 0.1s ease !important;
                    }
                    #global-clock-panel:active { transform: scale(0.95) !important; }
                    #global-clock-time {
                        font-size: 26px !important;
                        font-weight: 900 !important;
                        color: #000000 !important;
                        margin: 0 !important;
                        line-height: 1.1 !important;
                    }
                    #global-clock-date {
                        font-size: 14px !important;
                        font-weight: 700 !important;
                        color: #000000 !important;
                        margin-top: 5px !important;
                        white-space: nowrap !important;
                    }
                `;
                (document.head || document.documentElement).appendChild(styleClock);
            }

            function updateGlobalClock() {
                if (window.__globalClockDismissed) return;
                let clock = document.getElementById('global-clock-panel');
                if (!clock) {
                    clock = document.createElement('div');
                    clock.id = 'global-clock-panel';
                    clock.title = "Click para cerrar";

                    const timeDiv = document.createElement('div');
                    timeDiv.id = 'global-clock-time';

                    const dateDiv = document.createElement('div');
                    dateDiv.id = 'global-clock-date';

                    clock.appendChild(timeDiv);
                    clock.appendChild(dateDiv);

                    clock.onclick = () => {
                        clock.style.opacity = '0';
                        window.__globalClockDismissed = true;
                        setTimeout(() => clock.remove(), 300);
                    };

                    (document.body || document.documentElement).appendChild(clock);
                }

                const now = new Date();
                let hours = now.getHours();
                const ampm = hours >= 12 ? 'pm' : 'am';
                hours = hours % 12 || 12;
                const minutes = String(now.getMinutes()).padStart(2, '0');
                const seconds = String(now.getSeconds()).padStart(2, '0');
                const timeString = `${hours}:${minutes}:${seconds}${ampm}`;

                const dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
                const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

                const diaNombre = dias[now.getDay()];
                const diaNum = now.getDate();
                const mesNombre = meses[now.getMonth()];
                const mesNum = String(now.getMonth() + 1).padStart(2, '0');
                const dateString = `${diaNombre} ${diaNum} ${mesNombre} (${mesNum}) ${now.getFullYear()}`;

                const timeDiv = document.getElementById('global-clock-time');
                const dateDiv = document.getElementById('global-clock-date');

                if (timeDiv) timeDiv.textContent = timeString;
                if (dateDiv) dateDiv.textContent = dateString;
            }

            updateGlobalClock();
            if (!window.__globalClockInterval) {
                window.__globalClockInterval = setInterval(updateGlobalClock, 1000);
            }
        }
    }

    // ==========================================
    // 2. MÓDULO GMAIL (mail.google.com) - tm.0.js
    // ==========================================
    if (url.includes('mail.google.com')) {
        // Only layout adjustments for Gmail
        setInterval(() => {
            const hangouts = document.querySelector('div[role="complementary"]');
            if (hangouts) {
                hangouts.style.width = '350px';
                hangouts.style.maxWidth = '350px';
                hangouts.style.minWidth = '350px';
            }
        }, 1000);
    }

    // ==========================================
    // 3. MÓDULO GOOGLE MEET (meet.google.com) - tm.2, tm.3, tm.7
    // ==========================================
    if (url.includes('meet.google.com')) {
        // --- 3.1 Fondo Blanco con Switch (tm.2.js) ---
        if (!document.getElementById('fondo-blanco-estilos')) {
            const estiloMeet = document.createElement('style');
            estiloMeet.id = 'fondo-blanco-estilos';
            estiloMeet.textContent = `
                body.fondo-blanco-activo,
                body.fondo-blanco-activo main,
                body.fondo-blanco-activo .T4LgNb,
                body.fondo-blanco-activo #yDmH0d {
                    background: white !important;
                    background-color: white !important;
                }
                body.fondo-blanco-activo .XEazBc,
                body.fondo-blanco-activo .notranslate {
                    color: #202124 !important;
                }
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc,
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .FKJK2b,
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .ZrmAYe,
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .koV58,
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .LBDzPb,
                body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .p2hjYe {
                    background: white !important;
                    background-color: white !important;
                }
                body.fondo-blanco-activo [style*="--tile-blurred-image-url"] {
                    --tile-blurred-image-url: none !important;
                }
            `;
            (document.head || document.documentElement).appendChild(estiloMeet);
        }

        if (window.__fondoBlancoActivo === undefined) {
            window.__fondoBlancoActivo = true;
        }

        let botonSwitch = document.getElementById('fondo-blanco-switch');
        if (!botonSwitch) {
            botonSwitch = document.createElement('button');
            botonSwitch.id = 'fondo-blanco-switch';
            botonSwitch.style.cssText = `
                position: fixed;
                top: 20px;
                left: 20px;
                z-index: 9999;
                padding: 10px 20px;
                color: white;
                border: none;
                border-radius: 5px;
                cursor: pointer;
                font-size: 14px;
                font-weight: bold;
                box-shadow: 0 2px 5px rgba(0,0,0,0.2);
                transition: all 0.3s ease;
            `;

            const applySwitchState = () => {
                if (window.__fondoBlancoActivo) {
                    document.body.classList.add('fondo-blanco-activo');
                    botonSwitch.textContent = '🎨 Fondo Blanco ON';
                    botonSwitch.style.background = '#4CAF50';
                } else {
                    document.body.classList.remove('fondo-blanco-activo');
                    botonSwitch.textContent = '⬜ Fondo Blanco OFF';
                    botonSwitch.style.background = '#f44336';
                }
            };

            botonSwitch.addEventListener('mouseenter', () => botonSwitch.style.transform = 'scale(1.05)');
            botonSwitch.addEventListener('mouseleave', () => botonSwitch.style.transform = 'scale(1)');
            botonSwitch.addEventListener('click', () => {
                window.__fondoBlancoActivo = !window.__fondoBlancoActivo;
                applySwitchState();
            });

            document.body.appendChild(botonSwitch);
            applySwitchState();
        }

        // --- 3.2 Varita Blanca (tm.3.js) ---
        if (!document.getElementById('varita-magica-estilos')) {
            const estiloVarita = document.createElement('style');
            estiloVarita.id = 'varita-magica-estilos';
            estiloVarita.textContent = `
                .varita-cursor-activa { cursor: crosshair !important; }
                .varita-highlight { outline: 2px solid #4285f4 !important; outline-offset: -2px; }
            `;
            (document.head || document.documentElement).appendChild(estiloVarita);
        }

        let botonVarita = document.getElementById('varita-magica-btn');
        if (!botonVarita) {
            botonVarita = document.createElement('button');
            botonVarita.id = 'varita-magica-btn';
            botonVarita.textContent = '🪄 Varita Mágica';
            botonVarita.style.cssText = `
                position: fixed;
                top: 70px;
                left: 20px;
                z-index: 2147483647;
                padding: 10px 20px;
                background: #5f6368;
                color: white;
                border: none;
                border-radius: 5px;
                cursor: pointer;
                font-size: 14px;
                font-weight: bold;
                box-shadow: 0 2px 5px rgba(0,0,0,0.2);
                transition: all 0.3s ease;
            `;

            let varitaActiva = false;

            const blanquearElemento = (e) => {
                if (!varitaActiva) return;
                e.preventDefault();
                e.stopPropagation();

                const el = e.target;
                el.style.setProperty('background', 'white', 'important');
                el.style.setProperty('background-color', 'white', 'important');
                el.style.setProperty('color', '#202124', 'important');

                if (el.tagName === 'VIDEO') el.style.setProperty('display', 'none', 'important');
                el.querySelectorAll('video').forEach(v => v.style.setProperty('display', 'none', 'important'));
                el.querySelectorAll('canvas').forEach(c => c.style.setProperty('opacity', '0', 'important'));

                desactivarModoVarita();
            };

            const activarModoVarita = () => {
                varitaActiva = true;
                document.body.classList.add('varita-cursor-activa');
                botonVarita.textContent = '🪄 Varita: LISTO';
                botonVarita.style.background = '#fbbc04';
                document.addEventListener('click', blanquearElemento, { capture: true, once: true });
            };

            const desactivarModoVarita = () => {
                varitaActiva = false;
                document.body.classList.remove('varita-cursor-activa');
                botonVarita.textContent = '🪄 Varita Mágica';
                botonVarita.style.background = '#5f6368';
            };

            botonVarita.addEventListener('click', (e) => {
                e.stopPropagation();
                if (!varitaActiva) activarModoVarita();
                else desactivarModoVarita();
            });

            document.body.appendChild(botonVarita);
        }

        // --- 3.3 Google Meet Opener Auto (tm.7.js) ---
        function parsearHoraReunion(horaStr) {
            const limpia = horaStr.replace(/[\u202f\u00a0]/g, ' ').trim().toLowerCase();
            const match = limpia.match(/^(\d+):(\d+)\s*(a\.m\.|p\.m\.)$/);
            if (!match) return null;
            let [_, horas, minutos, periodo] = match;
            horas = parseInt(horas, 10);
            minutos = parseInt(minutos, 10);
            if (periodo.includes('p.m.') && horas < 12) horas += 12;
            if (periodo.includes('a.m.') && horas === 12) horas = 0;
            const hoy = new Date();
            hoy.setHours(horas, minutos, 0, 0);
            return hoy;
        }

        function checkAutoMeetOpen() {
            if (isMonkeyPaused()) return;
            const divsConAriaLabel = document.querySelectorAll('div[aria-label]');
            const ahora = new Date();
            divsConAriaLabel.forEach((div) => {
                const ariaLabel = div.getAttribute('aria-label');
                if (ariaLabel && ariaLabel.startsWith('De ')) {
                    const matchHora = ariaLabel.match(/^De\s+([0-9]{1,2}:[0-9]{2}\s*[a|p]\.m\.)/i);
                    if (matchHora) {
                        const textoHoraOriginal = matchHora[1];
                        const horaReunion = parsearHoraReunion(textoHoraOriginal);
                        if (horaReunion) {
                            const diferenciaMinutos = (ahora - horaReunion) / 60000;
                            if (diferenciaMinutos >= -5 && diferenciaMinutos <= 15) {
                                const divHijo = Array.from(document.querySelectorAll('div'))
                                    .find(d => d.textContent.replace(/[\u202f\u00a0]/g, ' ').trim() === textoHoraOriginal.replace(/[\u202f\u00a0]/g, ' ').trim());
                                if (divHijo && divHijo.parentElement) {
                                    const callId = divHijo.parentElement.getAttribute('data-call-id');
                                    if (callId && !window.__reunionesAbiertas.has(callId)) {
                                        const urlMeet = `https://meet.google.com/${callId}?authuser=1`;
                                        const opcionesPopup = "width=800,height=600,scrollbars=yes,resizable=yes";

                                        const speakText = (txt) => {
                                            const msg = new SpeechSynthesisUtterance(txt);
                                            msg.lang = 'es-ES';
                                            window.speechSynthesis.speak(msg);
                                        };

                                        speakText('Ingresando automáticamente a una llamada.');

                                        const horas24 = ahora.getHours();
                                        const mins = ahora.getMinutes().toString().padStart(2, '0');
                                        let horas12 = horas24 % 12 || 12;
                                        let periodo = (horas24 >= 6 && horas24 < 12) ? "de la mañana" : (horas24 >= 12 && horas24 < 20) ? "de la tarde" : "de la noche";

                                        speakText(`Son las ${horas12} y ${mins} ${periodo}. Ingresando automáticamente a una llamada.`);

                                        window.open(urlMeet, "GoogleMeetPopup", opcionesPopup);
                                        window.__reunionesAbiertas.add(callId);
                                    }
                                }
                            }
                        }
                    }
                }
            });
        }

        if (!window.__meetAutoOpenInterval) {
            window.__meetAutoOpenInterval = setInterval(checkAutoMeetOpen, 5000);
        }
        checkAutoMeetOpen();
    }

    // ==========================================
    // 4. MÓDULO YOUTUBE (youtube.com) - tm.6.js
    // ==========================================
    if (url.includes('youtube.com')) {
        function forzarBlancoTotalYouTube() {
            const selectores = [
                'video',
                'img',
                '.ytp-videowall-still-image',
                'canvas',
                '.ytp-cued-thumbnail-overlay-image',
                'ytd-shorts-player-view-model video'
            ];
            const elementos = document.querySelectorAll(selectores.join(','));
            elementos.forEach(el => {
                el.style.setProperty('filter', 'brightness(0) invert(1)', 'important');
                el.style.setProperty('background-color', 'white', 'important');
                el.style.setProperty('opacity', '1', 'important');
                if (el.tagName.toLowerCase() === 'video') {
                    el.style.setProperty('visibility', 'visible', 'important');
                }
            });
        }

        if (!window.__ytWhiteoutInterval) {
            window.__ytWhiteoutInterval = setInterval(forzarBlancoTotalYouTube, 100);
        }
        forzarBlancoTotalYouTube();
    }

    // ==========================================
    // 5. MÓDULO LOCALHOST (localhost / 127.0.0.1) - tm.4 / tm.5
    // ==========================================


    // ==========================================
    // 6. MÓDULO TRADUCTOR ALEMÁN -> ESPAÑOL (DE->ES)
    // ==========================================
    function initGermanTranslator() {
        if (window.location.hostname === 'my419950.s4hana.cloud.sap') return;
        if (window.__germanTranslatorInitialized) return;
        window.__germanTranslatorInitialized = true;

        let modalCreated = false;

        function ensureModalInDOM() {
            let bd = document.getElementById('monkey-german-modal-backdrop');
            if (bd) return bd;
            if (!document.body) return null;

            // Construir el modal mediante DOM API (Compatible con Trusted Types de Google / Gmail)
            const backdrop = document.createElement('div');
            backdrop.id = 'monkey-german-modal-backdrop';
            backdrop.style.cssText = "position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;background:rgba(255,255,255,0.75)!important;backdrop-filter:blur(8px)!important;z-index:2147483647!important;display:none;align-items:center;justify-content:center;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif!important;";

            const modal = document.createElement('div');
            modal.id = 'monkey-german-modal';
            modal.style.cssText = 'background:#ffffff!important;border-radius:16px!important;width:90%!important;max-width:600px!important;box-shadow:0 12px 48px rgba(0,0,0,0.15)!important;border:1px solid #e0e0e0!important;overflow:hidden!important;display:flex!important;flex-direction:column!important;';

            // Header
            const header = document.createElement('div');
            header.style.cssText = 'padding:16px 20px!important;background:#f8f9fa!important;border-bottom:1px solid #e0e0e0!important;display:flex!important;justify-content:space-between!important;align-items:center!important;';
            const title = document.createElement('h2');
            title.id = 'monkey-german-title';
            title.style.cssText = 'margin:0!important;color:#202124!important;font-size:18px!important;font-weight:600!important;display:flex!important;align-items:center!important;gap:10px!important;';
            title.textContent = '🇩🇪 Redactar en Alemán';
            
            const headerRight = document.createElement('div');
            headerRight.style.cssText = 'display:flex!important;align-items:center!important;gap:8px!important;';

            const statusDiv = document.createElement('div');
            statusDiv.id = 'monkey-german-status';
            statusDiv.style.cssText = 'color:#5f6368!important;font-size:13px!important;';

            // Selector de Idioma de Reconocimiento
            const langSelect = document.createElement('select');
            langSelect.id = 'monkey-german-lang-select';
            langSelect.tabIndex = -1;
            langSelect.style.cssText = 'font-size:12px!important;padding:2px 6px!important;border-radius:6px!important;border:1px solid #dadce0!important;background:#fff!important;color:#202124!important;outline:none!important;cursor:pointer!important;';
            const langOpts = [
                { val: 'de-DE', label: '🇩🇪 Alemán' },
                { val: 'en-US', label: '🇺🇸 Inglés' },
                { val: 'es-ES', label: '🇪🇸 Español' }
            ];
            let currentLang = localStorage.getItem('monkey_speech_lang') || 'de-DE';
            langOpts.forEach(o => {
                const opt = document.createElement('option');
                opt.value = o.val;
                opt.textContent = o.label;
                if (o.val === currentLang) opt.selected = true;
                langSelect.appendChild(opt);
            });
            langSelect.onchange = () => {
                currentLang = langSelect.value;
                localStorage.setItem('monkey_speech_lang', currentLang);
                if (isListening) {
                    stopSpeechRecognition();
                    setTimeout(() => toggleSpeechRecognition(), 300);
                }
            };

            // Selector desplegable de dispositivo de micrófono
            const micSelect = document.createElement('select');
            micSelect.id = 'monkey-german-mic-select';
            micSelect.tabIndex = -1;
            micSelect.style.cssText = 'display:none!important;max-width:140px!important;font-size:12px!important;padding:3px 6px!important;border-radius:6px!important;border:1px solid #dadce0!important;background:#fff!important;color:#202124!important;outline:none!important;cursor:pointer!important;';

            // Botón de Micrófono Web Speech API
            const micBtn = document.createElement('button');
            micBtn.id = 'monkey-german-speech-mic-btn';
            micBtn.setAttribute('type', 'button');
            micBtn.tabIndex = -1;
            micBtn.setAttribute('title', 'Iniciar reconocimiento de voz');
            micBtn.textContent = '🎤';
            micBtn.style.cssText = 'background:#f1f3f4!important;border:1px solid #dadce0!important;font-size:16px!important;cursor:pointer!important;padding:4px 9px!important;border-radius:6px!important;display:flex!important;align-items:center!important;justify-content:center!important;transition:all 0.2s ease!important;outline:none!important;user-select:none!important;';

            const closeBtn = document.createElement('button');
            closeBtn.id = 'monkey-german-close-btn';
            closeBtn.setAttribute('type', 'button');
            closeBtn.setAttribute('aria-label', 'Cerrar');
            closeBtn.textContent = '✕';
            closeBtn.style.cssText = 'background:transparent!important;border:none!important;color:#5f6368!important;font-size:18px!important;font-weight:bold!important;cursor:pointer!important;padding:4px 8px!important;border-radius:6px!important;line-height:1!important;display:flex!important;align-items:center!important;justify-content:center!important;transition:background 0.2s,color 0.2s!important;outline:none!important;';
            closeBtn.addEventListener('mouseenter', () => {
                closeBtn.style.background = '#e8eaed';
                closeBtn.style.color = '#202124';
            });
            closeBtn.addEventListener('mouseleave', () => {
                closeBtn.style.background = 'transparent';
                closeBtn.style.color = '#5f6368';
            });
            closeBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                stopSpeechRecognition();
                closeModal(true);
            });

            // Onda de audio animada (Waveform Visualizer)
            const waveContainer = document.createElement('div');
            waveContainer.id = 'monkey-german-wave-container';
            waveContainer.style.cssText = 'display:none!important;align-items:center!important;gap:3px!important;height:18px!important;padding:0 4px!important;';
            for (let i = 0; i < 4; i++) {
                const bar = document.createElement('div');
                bar.className = 'monkey-wave-bar';
                bar.style.cssText = `width:3px!important;height:4px!important;background:#34a853!important;border-radius:2px!important;transition:height 0.1s ease!important;`;
                waveContainer.appendChild(bar);
            }

            headerRight.appendChild(langSelect);
            headerRight.appendChild(micSelect);
            headerRight.appendChild(micBtn);
            headerRight.appendChild(waveContainer);
            headerRight.appendChild(statusDiv);
            headerRight.appendChild(closeBtn);

            header.appendChild(title);
            header.appendChild(headerRight);

            // Phase 1 (Input)
            const phase1 = document.createElement('div');
            phase1.id = 'monkey-german-phase1';
            phase1.style.cssText = 'padding:20px!important;display:flex!important;flex-direction:column!important;gap:15px!important;';
            
            const inputArea = document.createElement('textarea');
            inputArea.id = 'monkey-german-input';
            inputArea.placeholder = 'Schreibe hier etwas auf Deutsch...';
            inputArea.style.cssText = 'width:100%!important;min-height:120px!important;background:#ffffff!important;color:#202124!important;border:1px solid #dadce0!important;border-radius:8px!important;padding:15px!important;font-size:16px!important;resize:vertical!important;outline:none!important;font-family:inherit!important;box-sizing:border-box!important;box-shadow:inset 0 1px 2px rgba(0,0,0,0.05)!important;';

            const p1Footer = document.createElement('div');
            p1Footer.style.cssText = 'display:flex!important;justify-content:space-between!important;align-items:center!important;color:#5f6368!important;font-size:13px!important;';
            
            const spanShift = document.createElement('span');
            const kbdShift = document.createElement('kbd');
            kbdShift.style.cssText = 'background:#f1f3f4;padding:2px 6px;border-radius:4px;color:#202124;border:1px solid #dadce0;font-family:monospace;';
            kbdShift.textContent = 'Shift + Enter';
            spanShift.appendChild(kbdShift);
            spanShift.append(' salto de línea');

            const p1Btns = document.createElement('div');
            p1Btns.style.cssText = 'display:flex!important;gap:15px!important;';

            const spanEsc = document.createElement('span');
            const kbdEsc = document.createElement('kbd');
            kbdEsc.style.cssText = 'background:#f1f3f4;padding:2px 6px;border-radius:4px;color:#202124;border:1px solid #dadce0;font-family:monospace;';
            kbdEsc.textContent = 'Esc';
            spanEsc.appendChild(kbdEsc);
            spanEsc.append(' Cancelar');

            const spanEnter = document.createElement('span');
            const kbdEnter = document.createElement('kbd');
            kbdEnter.style.cssText = 'background:#34a853;color:#fff;padding:2px 6px;border-radius:4px;font-weight:bold;font-family:monospace;';
            kbdEnter.textContent = 'Enter';
            spanEnter.appendChild(kbdEnter);
            spanEnter.append(' Traducir');

            p1Btns.appendChild(spanEsc);
            p1Btns.appendChild(spanEnter);
            p1Footer.appendChild(spanShift);
            p1Footer.appendChild(p1Btns);

            phase1.appendChild(inputArea);
            phase1.appendChild(p1Footer);

            // Phase 2 (Confirm)
            const phase2 = document.createElement('div');
            phase2.id = 'monkey-german-phase2';
            phase2.style.cssText = 'padding:20px!important;display:none;flex-direction:column!important;gap:15px!important;';

            const origBox = document.createElement('div');
            origBox.style.cssText = 'background:#fff8e1!important;border-radius:8px!important;padding:15px!important;border-left:4px solid #fbc02d!important;';
            const origLabel = document.createElement('div');
            origLabel.style.cssText = 'color:#795548!important;font-size:12px!important;margin-bottom:5px!important;text-transform:uppercase!important;letter-spacing:1px!important;font-weight:600!important;';
            origLabel.textContent = 'Original (Alemán)';
            const originalTextDiv = document.createElement('div');
            originalTextDiv.id = 'monkey-german-original-text';
            originalTextDiv.style.cssText = 'color:#3e2723!important;font-size:15px!important;white-space:pre-wrap!important;';
            origBox.appendChild(origLabel);
            origBox.appendChild(originalTextDiv);

            const transContainer = document.createElement('div');
            const transTitle = document.createElement('div');
            transTitle.style.cssText = 'color:#202124!important;font-size:16px!important;margin-bottom:10px!important;font-weight:500!important;';
            transTitle.textContent = '¿Usted quiso decir...?';
            const transBox = document.createElement('div');
            transBox.style.cssText = 'background:#e8f0fe!important;border-radius:8px!important;padding:15px!important;border-left:4px solid #1a73e8!important;';
            const translatedTextDiv = document.createElement('div');
            translatedTextDiv.id = 'monkey-german-translated-text';
            translatedTextDiv.style.cssText = 'color:#174ea6!important;font-size:18px!important;white-space:pre-wrap!important;font-weight:600!important;';
            transBox.appendChild(translatedTextDiv);
            transContainer.appendChild(transTitle);
            transContainer.appendChild(transBox);

            const p2Footer = document.createElement('div');
            p2Footer.style.cssText = 'display:flex!important;justify-content:flex-end!important;align-items:center!important;color:#5f6368!important;font-size:13px!important;margin-top:5px!important;gap:15px!important;';

            const spanEsc2 = document.createElement('span');
            const kbdEsc2 = document.createElement('kbd');
            kbdEsc2.style.cssText = 'background:#f1f3f4;padding:2px 6px;border-radius:4px;color:#202124;border:1px solid #dadce0;font-family:monospace;';
            kbdEsc2.textContent = 'Esc';
            spanEsc2.appendChild(kbdEsc2);
            spanEsc2.append(' Volver a corregir');

            const spanEnter2 = document.createElement('span');
            const kbdEnter2 = document.createElement('kbd');
            kbdEnter2.style.cssText = 'background:#1a73e8;color:#fff;padding:2px 6px;border-radius:4px;font-weight:bold;font-family:monospace;';
            kbdEnter2.textContent = 'Enter';
            spanEnter2.appendChild(kbdEnter2);
            spanEnter2.append(' Sí / Pegar Traducción');

            p2Footer.appendChild(spanEsc2);
            p2Footer.appendChild(spanEnter2);

            phase2.appendChild(origBox);
            phase2.appendChild(transContainer);
            phase2.appendChild(p2Footer);

            modal.appendChild(header);
            modal.appendChild(phase1);
            modal.appendChild(phase2);
            backdrop.appendChild(modal);

            document.body.appendChild(backdrop);

            // Conectar eventos del inputArea una sola vez
            inputArea.addEventListener('keydown', async (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    stopSpeechRecognition();
                    const text = inputArea.value.trim();
                    if (!text) return;
                    
                    const translated = await translateText(text);
                    if (translated) {
                        originalTextDiv.textContent = text;
                        translatedTextDiv.textContent = translated;
                        phase1.style.display = 'none';
                        phase2.style.display = 'flex';
                        currentPhase = 2;
                    }
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    stopSpeechRecognition();
                    closeModal(true);
                }
            });

            return backdrop;
        }

        ensureModalInDOM();

        // ----------------------------------------------------
        // RECONOCIMIENTO DE VOZ EXCLUSIVAMENTE EN ALEMÁN (de-DE)
        // Con Selector Dinámico y Persistente de Micrófono
        // ----------------------------------------------------
        let recognition = null;
        let isListening = false;
        let currentMediaStream = null;
        let selectedAudioDeviceId = localStorage.getItem('monkey_german_mic_id') || '';
        let speechReceivedInSession = false;
        let audioCaptureRetries = 0;
        async function populateAudioDevices(forceShow = false) {
            const els = getModalElements();
            if (!els.micSelect) return;

            try {
                if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) {
                    return;
                }

                const devices = await navigator.mediaDevices.enumerateDevices();
                const audioInputs = devices.filter(d => d.kind === 'audioinput');

                if (currentMediaStream) {
                    currentMediaStream.getTracks().forEach(t => t.stop());
                    currentMediaStream = null;
                }

                if (audioInputs.length === 0) return;

                els.micSelect.replaceChildren();
                audioInputs.forEach((dev, idx) => {
                    const opt = document.createElement('option');
                    opt.value = dev.deviceId;
                    opt.textContent = dev.label || `Micrófono ${idx + 1}`;
                    if (dev.deviceId === selectedAudioDeviceId || (!selectedAudioDeviceId && idx === 0)) {
                        opt.selected = true;
                    }
                    els.micSelect.appendChild(opt);
                });

                els.micSelect.style.setProperty('display', 'inline-block', 'important');

                els.micSelect.onchange = async () => {
                    selectedAudioDeviceId = els.micSelect.value;
                    localStorage.setItem('monkey_german_mic_id', selectedAudioDeviceId);
                    
                    if (isListening) {
                        stopSpeechRecognition();
                        setTimeout(() => toggleSpeechRecognition(), 300);
                    }
                };
            } catch (err) {
                console.warn('Error al enumerar micrófonos:', err);
            }
        }

        let waveAnimInterval = null;
        function updateWaveAnimation(active, intensity = 1) {
            const els = getModalElements();
            if (!els.waveContainer) return;

            if (active) {
                els.waveContainer.style.setProperty('display', 'inline-flex', 'important');
                if (!waveAnimInterval) {
                    waveAnimInterval = setInterval(() => {
                        const bars = els.waveContainer.querySelectorAll('.monkey-wave-bar');
                        bars.forEach((bar, idx) => {
                            const minH = 4;
                            const maxH = intensity > 1 ? 16 : 10;
                            const h = Math.floor(Math.random() * (maxH - minH + 1)) + minH;
                            bar.style.height = `${h}px`;
                            bar.style.background = intensity > 1 ? '#188038' : '#1a73e8';
                        });
                    }, 100);
                }
            } else {
                if (waveAnimInterval) {
                    clearInterval(waveAnimInterval);
                    waveAnimInterval = null;
                }
                els.waveContainer.style.setProperty('display', 'none', 'important');
                const bars = els.waveContainer.querySelectorAll('.monkey-wave-bar');
                bars.forEach(b => b.style.height = '4px');
            }
        }

        function updateMicButtonUI(listening) {
            const els = getModalElements();
            if (!els.micBtn) return;

            if (listening) {
                els.micBtn.textContent = '🔴';
                els.micBtn.title = 'Escuchando en Alemán (clic para detener)...';
                els.micBtn.style.background = '#fce8e6';
                els.micBtn.style.borderColor = '#d93025';
                els.micBtn.style.boxShadow = '0 0 8px rgba(217, 48, 37, 0.5)';
                updateWaveAnimation(true, 1);
                if (els.statusDiv) {
                    els.statusDiv.textContent = '🎙️ Sprechen Sie auf Deutsch...';
                    els.statusDiv.style.color = '#d93025';
                }
            } else {
                els.micBtn.textContent = '🎤';
                els.micBtn.title = 'Hablar en Alemán (de-DE)';
                els.micBtn.style.background = '#f1f3f4';
                els.micBtn.style.borderColor = '#dadce0';
                els.micBtn.style.boxShadow = 'none';
                updateWaveAnimation(false);
                if (els.statusDiv && els.statusDiv.textContent.includes('Sprechen')) {
                    els.statusDiv.textContent = '';
                    els.statusDiv.style.color = '#5f6368';
                }
            }
        }

        function stopSpeechRecognition() {
            updateWaveAnimation(false);
            if (currentMediaStream) {
                try {
                    currentMediaStream.getTracks().forEach(t => t.stop());
                } catch (e) {}
                currentMediaStream = null;
            }
            if (recognition) {
                try {
                    recognition.abort();
                } catch (e) {}
                recognition = null;
            }
            isListening = false;
            updateMicButtonUI(false);
        }

        async function toggleSpeechRecognition() {
            const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
            const els = getModalElements();

            if (!SpeechRecognition) {
                if (els.statusDiv) {
                    els.statusDiv.textContent = 'Reconocimiento de voz no soportado';
                    els.statusDiv.style.color = '#d93025';
                    setTimeout(() => { if (els.statusDiv) els.statusDiv.textContent = ''; }, 3000);
                }
                return;
            }

            if (isListening) {
                // Si detiene manualmente y no se capturó nada, desplegar el selector de micrófono
                if (!speechReceivedInSession) {
                    await populateAudioDevices(true);
                    if (els.statusDiv) {
                        els.statusDiv.textContent = 'Seleccione su micrófono';
                        els.statusDiv.style.color = '#d93025';
                        setTimeout(() => { if (els.statusDiv) els.statusDiv.textContent = ''; }, 4000);
                    }
                }
                stopSpeechRecognition();
                return;
            }

            try {
                if (recognition) {
                    try { recognition.abort(); } catch (e) {}
                    recognition = null;
                }

                const selectedLang = localStorage.getItem('monkey_speech_lang') || 'de-DE';
                monkeyDebugLog('Speech', `Iniciando sesión de SpeechRecognition (${selectedLang})...`);
                speechReceivedInSession = false;

                // Crear nueva instancia limpia de SpeechRecognition
                recognition = new SpeechRecognition();
                recognition.continuous = true;
                recognition.interimResults = true;
                recognition.lang = selectedLang;
                recognition.maxAlternatives = 1;

                recognition.onstart = () => {
                    isListening = true;
                    updateMicButtonUI(true);
                    monkeyDebugLog('Speech', 'Motor de voz iniciado correctamente (onstart).');
                };

                recognition.onaudiostart = () => {
                    audioCaptureRetries = 0;
                    monkeyDebugLog('Speech', 'Captura de audio iniciada por el navegador (onaudiostart).');
                };

                recognition.onsoundstart = () => {
                    monkeyDebugLog('Speech', 'Sonido detectado en micrófono (onsoundstart).');
                    updateWaveAnimation(true, 2);
                    const modalEls = getModalElements();
                    if (modalEls.statusDiv && isListening) {
                        modalEls.statusDiv.textContent = '🎙️ Escuchando señal...';
                        modalEls.statusDiv.style.color = '#1a73e8';
                    }
                };

                recognition.onspeechstart = () => {
                    monkeyDebugLog('Speech', 'Voz detectada (onspeechstart).');
                    updateWaveAnimation(true, 3);
                    const modalEls = getModalElements();
                    if (modalEls.statusDiv && isListening) {
                        modalEls.statusDiv.textContent = '🎙️ Procesando voz en alemán...';
                        modalEls.statusDiv.style.color = '#188038';
                    }
                };

                recognition.onresult = (event) => {
                    const modalEls = getModalElements();
                    if (!modalEls.inputArea) return;

                    let finalTranscript = '';
                    let interimTranscript = '';

                    for (let i = event.resultIndex; i < event.results.length; ++i) {
                        if (event.results[i].isFinal) {
                            finalTranscript += event.results[i][0].transcript;
                        } else {
                            interimTranscript += event.results[i][0].transcript;
                        }
                    }

                    monkeyDebugLog('Speech', 'Resultado de transcripción recibido', { final: finalTranscript, interim: interimTranscript });

                    let currentText = modalEls.inputArea._savedBaseText || '';
                    if (!modalEls.inputArea._savedBaseText) {
                        modalEls.inputArea._savedBaseText = modalEls.inputArea.value;
                        currentText = modalEls.inputArea._savedBaseText;
                    }

                    if (interimTranscript) {
                        const separator = currentText && !currentText.endsWith(' ') && !currentText.endsWith('\n') ? ' ' : '';
                        modalEls.inputArea.value = currentText + separator + interimTranscript.trim();
                        modalEls.inputArea.scrollTop = modalEls.inputArea.scrollHeight;
                        if (modalEls.statusDiv) {
                            modalEls.statusDiv.textContent = `🎙️ "${interimTranscript.trim()}"`;
                            modalEls.statusDiv.style.color = '#188038';
                        }
                    }

                    if (finalTranscript) {
                        speechReceivedInSession = true;
                        const separator = currentText && !currentText.endsWith(' ') && !currentText.endsWith('\n') ? ' ' : '';
                        const newFull = currentText + separator + finalTranscript.trim();
                        modalEls.inputArea.value = newFull;
                        modalEls.inputArea._savedBaseText = newFull;
                        modalEls.inputArea.dispatchEvent(new Event('input', { bubbles: true }));
                        modalEls.inputArea.scrollTop = modalEls.inputArea.scrollHeight;
                        if (modalEls.statusDiv) {
                            modalEls.statusDiv.textContent = '🎙️ Transcrito con éxito';
                            modalEls.statusDiv.style.color = '#188038';
                        }
                    }
                };

                recognition.onerror = async (event) => {
                    monkeyDebugLog('SpeechError', `Error en SpeechRecognition: ${event.error}`, { error: event.error, message: event.message });
                    const modalEls = getModalElements();
                    if (event.error === 'no-speech' || event.error === 'aborted') {
                        // Silencio o aborto por reinicio limpio
                        return;
                    }
                    
                    if (event.error === 'audio-capture') {
                        if (audioCaptureRetries < 5) {
                            audioCaptureRetries++;
                            monkeyDebugLog('Speech', `Reconectando audio automáticamente (${audioCaptureRetries}/5)...`);
                            if (modalEls.statusDiv) {
                                modalEls.statusDiv.textContent = '🎙️ Reconectando micrófono...';
                                modalEls.statusDiv.style.color = '#e37400';
                            }
                            if (recognition) {
                                try { recognition.abort(); } catch (e) {}
                                recognition = null;
                            }
                            setTimeout(() => {
                                if (currentPhase === 1) {
                                    isListening = false;
                                    toggleSpeechRecognition();
                                }
                            }, 500);
                            return;
                        }
                        audioCaptureRetries = 0;
                        isListening = false;
                        updateMicButtonUI(false);
                        if (modalEls.statusDiv) {
                            modalEls.statusDiv.textContent = 'Micrófono no disponible o bloqueado';
                            modalEls.statusDiv.style.color = '#d93025';
                        }
                        await populateAudioDevices(true);
                    } else if (event.error === 'not-allowed') {
                        audioCaptureRetries = 0;
                        isListening = false;
                        updateMicButtonUI(false);
                        if (modalEls.statusDiv) {
                            modalEls.statusDiv.textContent = 'Permiso de micrófono denegado';
                            modalEls.statusDiv.style.color = '#d93025';
                        }
                        await populateAudioDevices(true);
                    } else {
                        if (modalEls.statusDiv) {
                            modalEls.statusDiv.textContent = `Mic: ${event.error}`;
                            modalEls.statusDiv.style.color = '#d93025';
                        }
                    }
                    stopSpeechRecognition();
                };

                recognition.onend = async () => {
                    monkeyDebugLog('Speech', 'Sesión SpeechRecognition finalizada (onend).', { wasListening: isListening, currentPhase: currentPhase });
                    if (isListening && currentPhase === 1) {
                        setTimeout(() => {
                            if (isListening && currentPhase === 1) {
                                try {
                                    toggleSpeechRecognition();
                                } catch (err) {}
                            }
                        }, 300);
                    } else {
                        isListening = false;
                        updateMicButtonUI(false);
                    }
                };

                recognition.start();
            } catch (err) {
                monkeyDebugLog('SpeechException', `Excepción al arrancar SpeechRecognition: ${err.message}`, { err: String(err) });
                await populateAudioDevices(true);
                stopSpeechRecognition();
            }
        }

        function getModalElements() {
            ensureModalInDOM();
            return {
                backdrop: document.getElementById('monkey-german-modal-backdrop'),
                phase1: document.getElementById('monkey-german-phase1'),
                phase2: document.getElementById('monkey-german-phase2'),
                inputArea: document.getElementById('monkey-german-input'),
                originalTextDiv: document.getElementById('monkey-german-original-text'),
                translatedTextDiv: document.getElementById('monkey-german-translated-text'),
                statusDiv: document.getElementById('monkey-german-status'),
                micBtn: document.getElementById('monkey-german-speech-mic-btn'),
                micSelect: document.getElementById('monkey-german-mic-select'),
                waveContainer: document.getElementById('monkey-german-wave-container')
            };
        }

        let currentTarget = null;
        let currentPhase = 0; // 0: closed, 1: input, 2: confirm

        function closeModal(skipTargetOnce = false) {
            stopSpeechRecognition();
            const els = getModalElements();
            if (els.backdrop) els.backdrop.style.display = 'none';
            currentPhase = 0;
            if (currentTarget) {
                if (skipTargetOnce) {
                    currentTarget._monkeySkipTranslator = true;
                }
                currentTarget.focus();
                currentTarget = null;
            }
        }

        function openModal(target) {
            if (!window.__germanTranslatorActive) return;
            if (target._monkeySkipTranslator) return;
            
            const els = getModalElements();
            if (!els.backdrop || !els.phase1 || !els.inputArea) return;

            currentTarget = target;
            currentPhase = 1;
            els.phase1.style.display = 'flex';
            els.phase2.style.display = 'none';
            els.backdrop.style.display = 'flex';
            els.statusDiv.textContent = '';
            
            // Conectar el botón de micrófono exclusivamente a clics del mouse
            if (els.micBtn) {
                els.micBtn.onclick = (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    toggleSpeechRecognition();
                };
            }

            els.inputArea.value = ''; 
            els.inputArea._savedBaseText = '';
            populateAudioDevices(true);
            setTimeout(() => {
                els.inputArea.focus();
            }, 100);
        }

        async function translateText(text) {
            const els = getModalElements();
            if (els.statusDiv) els.statusDiv.textContent = 'Traduciendo...';
            try {
                const res = await gmFetch(`https://translate.googleapis.com/translate_a/single?client=gtx&sl=de&tl=es&dt=t&q=${encodeURIComponent(text)}`);
                const data = await res.json();
                let translated = '';
                if (data && data[0]) {
                    data[0].forEach(item => {
                        if (item[0]) translated += item[0];
                    });
                }
                if (els.statusDiv) els.statusDiv.textContent = '';
                return translated;
            } catch (err) {
                console.error('Translation error:', err);
                if (els.statusDiv) els.statusDiv.textContent = 'Error de traducción';
                return null;
            }
        }

        function insertTextIntoTarget(text, target) {
            if (!target) return;

            // En caso de que el elemento esté bloqueado o deshabilitado, lo intentamos reactivar
            try {
                if (target.disabled) target.disabled = false;
                if (target.readOnly) target.readOnly = false;
            } catch (e) {}

            try {
                target.focus();
            } catch (e) {}
            
            if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
                const success = document.execCommand('insertText', false, text);
                if (!success) {
                    const start = target.selectionStart ?? target.value.length;
                    const end = target.selectionEnd ?? target.value.length;
                    target.value = target.value.substring(0, start) + text + target.value.substring(end);
                    target.selectionStart = target.selectionEnd = start + text.length;
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                    target.dispatchEvent(new Event('change', { bubbles: true }));
                }
            } else if (target.isContentEditable || target.getAttribute('contenteditable') === 'true' || target.getAttribute('role') === 'textbox') {
                const success = document.execCommand('insertText', false, text);
                if (!success) {
                    target.textContent += text;
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                }
            } else {
                // Si es un div/elemento genérico (por ejemplo en chats especiales)
                try {
                    document.execCommand('insertText', false, text);
                } catch (e) {}
                if (target.value !== undefined) {
                    target.value = text;
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                } else if (target.isContentEditable) {
                    target.innerText = text;
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                }
            }

            // Respaldo adicional: también lo dejamos copiado en el portapapeles por comodidad
            try {
                navigator.clipboard.writeText(text).catch(() => {});
            } catch (e) {}
        }

        function getEditableTarget(target) {
            if (!target || !target.getAttribute) return null;
            const els = getModalElements();
            if (els.backdrop && els.backdrop.contains(target)) return null;

            if (target.tagName === 'INPUT') {
                const type = target.type ? target.type.toLowerCase() : 'text';
                const ignoredTypes = ['password', 'hidden', 'checkbox', 'radio', 'file', 'button', 'submit', 'reset', 'image', 'color', 'date', 'time', 'range'];
                if (!ignoredTypes.includes(type) && !target.readOnly && !target.disabled) {
                    return target;
                }
                return null;
            }

            if (target.tagName === 'TEXTAREA') {
                if (!target.readOnly && !target.disabled) return target;
                return null;
            }

            const editableParent = target.closest ? target.closest('[contenteditable="true"], [role="textbox"], [g_editable="true"]') : null;
            if (editableParent) return editableParent;

            if (target.isContentEditable || target.getAttribute('contenteditable') === 'true' || target.getAttribute('role') === 'textbox') {
                return target;
            }

            return null;
        }

        function handleFocus(target) {
            if (!target) return;
            if (!window.__germanTranslatorActive) return;
            if (isMonkeyPaused()) return;

            const editable = getEditableTarget(target);
            if (editable) {
                openModal(editable);
            }
        }

        document.addEventListener('focus', (e) => {
            const path = e.composedPath && e.composedPath();
            const target = (path && path.length > 0) ? path[0] : e.target;
            handleFocus(target);
        }, true);

        document.addEventListener('click', (e) => {
            if (currentPhase !== 0) return;
            const path = e.composedPath && e.composedPath();
            const target = (path && path.length > 0) ? path[0] : e.target;
            handleFocus(target);
        }, true);

        // Fallback robusto por polling (para GChat, YouTube, etc. que secuestran focus)
        let lastActiveElement = null;
        setInterval(() => {
            if (!window.__germanTranslatorActive || currentPhase !== 0 || isMonkeyPaused()) return;
            
            let target = document.activeElement;
            if (target && target.shadowRoot) {
                target = target.shadowRoot.activeElement || target;
            }

            if (target && target !== lastActiveElement && target !== document.body && target !== document.documentElement) {
                lastActiveElement = target;
                const els = getModalElements();
                if ((!els.backdrop || !els.backdrop.contains(target)) && !target._monkeySkipTranslator) {
                    handleFocus(target);
                }
            } else if (!target || target === document.body) {
                lastActiveElement = null;
            }
        }, 300);

        document.addEventListener('blur', (e) => {
            const path = e.composedPath && e.composedPath();
            const target = (path && path.length > 0) ? path[0] : e.target;
            if (target && target._monkeySkipTranslator) {
                setTimeout(() => {
                    target._monkeySkipTranslator = false;
                }, 200);
            }
        }, true);

        document.addEventListener('keydown', (e) => {
            // Atajo Ctrl+Q (o Cmd+Q en Mac) para abrir manualmente el traductor
            if ((e.ctrlKey || e.metaKey) && (e.key === 'q' || e.key === 'Q')) {
                e.preventDefault();
                e.stopPropagation();

                // Si ya está abierto, lo cerramos
                if (currentPhase !== 0) {
                    closeModal(true);
                    return;
                }

                let target = document.activeElement;
                if (target && target.shadowRoot) {
                    target = target.shadowRoot.activeElement || target;
                }

                let editable = getEditableTarget(target);
                if (!editable && target && target !== document.body && target !== document.documentElement) {
                    editable = target;
                }

                // Si no hay elemento activo o es el body, buscamos el primer input/textarea/contenteditable visible
                if (!editable || editable === document.body) {
                    editable = document.querySelector('input:not([type="hidden"]):not([disabled]):not([readonly]), textarea:not([disabled]):not([readonly]), [contenteditable="true"], [role="textbox"]') || document.body;
                }

                if (editable) {
                    editable._monkeySkipTranslator = false;
                    openModal(editable);
                }
                return;
            }

            if (currentPhase === 2) {
                const els = getModalElements();
                if (e.key === 'Enter') {
                    e.preventDefault();
                    e.stopPropagation();
                    const translatedText = els.translatedTextDiv ? els.translatedTextDiv.textContent : '';
                    const target = currentTarget;
                    closeModal(true);
                    setTimeout(() => insertTextIntoTarget(translatedText, target), 10);
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    e.stopPropagation();
                    if (els.phase2) els.phase2.style.display = 'none';
                    if (els.phase1) els.phase1.style.display = 'flex';
                    currentPhase = 1;
                    if (els.inputArea) setTimeout(() => els.inputArea.focus(), 50);
                }
            }
        }, true);
    }

    initGermanTranslator();
})();
