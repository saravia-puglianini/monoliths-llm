// Estado global persistente
window.__whiteoutState = window.__whiteoutState || { video: true, img: true };
window.__micActive = window.__micActive ?? null;
window.__reunionesAbiertas = window.__reunionesAbiertas || new Set();

(async function () {
    'use strict';

    const url = window.location.href;
    const host = window.location.hostname;

    // ==========================================
    // 1. MÓDULO GLOBAL: BARRA DE CONTROLES BASE
    // ==========================================
    const SERVER_URL = 'http://127.0.0.1:8888';

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

    if (!document.body) return;

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
            const controller = new AbortController();
            const id = setTimeout(() => controller.abort(), 1500);
            const res = await fetch(`${SERVER_URL}${endpoint}`, { signal: controller.signal });
            clearTimeout(id);
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
    // 2. MÓDULO GMAIL (mail.google.com) - tm.0.js
    // ==========================================
    if (url.includes('mail.google.com')) {
        if (!document.getElementById('gmail-clock-style')) {
            const styleGmail = document.createElement('style');
            styleGmail.id = 'gmail-clock-style';
            styleGmail.textContent = `
                #custom-gmail-clock {
                    position: fixed !important;
                    top: 80px !important;
                    right: 25px !important;
                    background-color: #90ee90 !important;
                    padding: 12px 20px !important;
                    border-radius: 10px !important;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.3) !important;
                    z-index: 2147483647 !important;
                    pointer-events: none !important;
                    display: flex !important;
                    flex-direction: column !important;
                    align-items: flex-end !important;
                    border: 2px solid #2e7d32 !important;
                    min-width: 200px !important;
                    font-family: Arial, sans-serif !important;
                }
                #gmail-clock-time {
                    font-size: 24px !important;
                    font-weight: 900 !important;
                    color: #000000 !important;
                    margin-bottom: 4px !important;
                }
                #gmail-clock-date {
                    font-size: 14px !important;
                    font-weight: 700 !important;
                    color: #000000 !important;
                }
            `;
            (document.head || document.documentElement).appendChild(styleGmail);
        }

        function updateGmailClock() {
            let clock = document.getElementById('custom-gmail-clock');
            if (!clock) {
                clock = document.createElement('div');
                clock.id = 'custom-gmail-clock';
                document.body.appendChild(clock);
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
            const año = now.getFullYear();

            const dateString = `${diaNombre} ${diaNum} ${mesNombre} (${mesNum}) ${año}`;

            let timeDiv = document.getElementById('gmail-clock-time');
            let dateDiv = document.getElementById('gmail-clock-date');

            if (!timeDiv) {
                timeDiv = document.createElement('div');
                timeDiv.id = 'gmail-clock-time';
                clock.appendChild(timeDiv);
            }
            if (!dateDiv) {
                dateDiv = document.createElement('div');
                dateDiv.id = 'gmail-clock-date';
                clock.appendChild(dateDiv);
            }

            timeDiv.textContent = timeString;
            dateDiv.textContent = dateString;
        }

        updateGmailClock();
        if (!window.__gmailClockInterval) {
            window.__gmailClockInterval = setInterval(updateGmailClock, 1000);
        }
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
    if (host === 'localhost' || host === '127.0.0.1') {
        if (!document.getElementById('local-clock-style')) {
            const styleLocal = document.createElement('style');
            styleLocal.id = 'local-clock-style';
            styleLocal.textContent = `
                #local-clock-panel {
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
                #local-clock-panel:active { transform: scale(0.95) !important; }
                #local-clock-time {
                    font-size: 26px !important;
                    font-weight: 900 !important;
                    color: #000000 !important;
                    margin: 0 !important;
                    line-height: 1.1 !important;
                }
                #local-clock-date {
                    font-size: 14px !important;
                    font-weight: 700 !important;
                    color: #000000 !important;
                    margin-top: 5px !important;
                    white-space: nowrap !important;
                }
            `;
            (document.head || document.documentElement).appendChild(styleLocal);
        }

        function updateLocalClock() {
            if (window.__localClockDismissed) return;
            let clock = document.getElementById('local-clock-panel');
            if (!clock) {
                clock = document.createElement('div');
                clock.id = 'local-clock-panel';
                clock.title = "Click para cerrar";

                const timeDiv = document.createElement('div');
                timeDiv.id = 'local-clock-time';

                const dateDiv = document.createElement('div');
                dateDiv.id = 'local-clock-date';

                clock.appendChild(timeDiv);
                clock.appendChild(dateDiv);

                clock.onclick = () => {
                    clock.style.opacity = '0';
                    window.__localClockDismissed = true;
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

            const timeDiv = document.getElementById('local-clock-time');
            const dateDiv = document.getElementById('local-clock-date');

            if (timeDiv) timeDiv.textContent = timeString;
            if (dateDiv) dateDiv.textContent = dateString;
        }

        updateLocalClock();
        if (!window.__localClockInterval) {
            window.__localClockInterval = setInterval(updateLocalClock, 1000);
        }
    }
})();
