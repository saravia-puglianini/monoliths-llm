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
                }
            ];

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
            header.style.cssText = 'padding:20px!important;background:#f8f9fa!important;border-bottom:1px solid #e0e0e0!important;display:flex!important;justify-content:space-between!important;align-items:center!important;';
            const title = document.createElement('h2');
            title.id = 'monkey-german-title';
            title.style.cssText = 'margin:0!important;color:#202124!important;font-size:18px!important;font-weight:600!important;display:flex!important;align-items:center!important;gap:10px!important;';
            title.textContent = '🇩🇪 Redactar en Alemán';
            const statusDiv = document.createElement('div');
            statusDiv.id = 'monkey-german-status';
            statusDiv.style.cssText = 'color:#5f6368!important;font-size:13px!important;';
            header.appendChild(title);
            header.appendChild(statusDiv);

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
                    closeModal(true);
                }
            });

            return backdrop;
        }

        ensureModalInDOM();

        function getModalElements() {
            ensureModalInDOM();
            return {
                backdrop: document.getElementById('monkey-german-modal-backdrop'),
                phase1: document.getElementById('monkey-german-phase1'),
                phase2: document.getElementById('monkey-german-phase2'),
                inputArea: document.getElementById('monkey-german-input'),
                originalTextDiv: document.getElementById('monkey-german-original-text'),
                translatedTextDiv: document.getElementById('monkey-german-translated-text'),
                statusDiv: document.getElementById('monkey-german-status')
            };
        }

        let currentTarget = null;
        let currentPhase = 0; // 0: closed, 1: input, 2: confirm

        function closeModal(skipTargetOnce = false) {
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
            
            els.inputArea.value = ''; 
            setTimeout(() => els.inputArea.focus(), 50);
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
            if (!window.__germanTranslatorActive || currentPhase !== 0) return;
            
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

        const els = getModalElements();
        if (els.inputArea) {
            els.inputArea.addEventListener('keydown', async (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    const text = els.inputArea.value.trim();
                    if (!text) return;
                    
                    const translated = await translateText(text);
                    if (translated) {
                        els.originalTextDiv.textContent = text;
                        els.translatedTextDiv.textContent = translated;
                        els.phase1.style.display = 'none';
                        els.phase2.style.display = 'flex';
                        currentPhase = 2;
                    }
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    closeModal(true);
                }
            });
        }

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
