// Estado global persistente
window.__whiteoutState = window.__whiteoutState || { video: true, img: true };
window.__micActive = window.__micActive ?? null;

(async function () {
    'use strict';

    const SERVER_URL = 'http://127.0.0.1:8888';

    // 1. Aplicar Estilos CSS Dinámicos (Sin necesidad de recorrer el DOM con loops de JS)
    let style = document.getElementById('whiteout-dynamic-css');
    if (!style) {
        style = document.createElement('style');
        style.id = 'whiteout-dynamic-css';
        (document.head || document.documentElement).appendChild(style);
    }

    style.textContent = `
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

    // 2. Panel Flotante
    let container = document.getElementById('control-panel-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'control-panel-container';
        container.style.cssText = 'position:fixed!important;bottom:25px!important;right:25px!important;z-index:2147483647!important;display:flex!important;gap:10px!important;align-items:center!important;user-select:none!important;';
        document.body.appendChild(container);
    }

    // Configuración de botones para reducir redundancia de código
    const buttons = [
        {
            id: 'btn-toggle-video',
            getSymbol: () => '🎬',
            getTitle: () => `Blanqueo Video: ${window.__whiteoutState.video ? 'ACTIVO (Clic para Mostrar)' : 'DESACTIVADO (Clic para Blanquear)'}`,
            getBg: () => window.__whiteoutState.video ? '#1565c0' : '#424242',
            getOpacity: () => window.__whiteoutState.video ? '1' : '0.45',
            onClick: () => {
                window.__whiteoutState.video = !window.__whiteoutState.video;
                updateUI();
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
                updateUI();
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

    function updateUI() {
        // Actualizar hoja de estilos dinámica
        if (style) {
            style.textContent = `
                ${window.__whiteoutState.video ? 'video, canvas, ytd-shorts-player-view-model video { filter: brightness(0) invert(1) !important; background-color: white !important; opacity: 1 !important; visibility: visible !important; }' : ''}
                ${window.__whiteoutState.img ? 'img, image, .ytp-videowall-still-image, .ytp-cued-thumbnail-overlay-image, [style*="background-image"] { filter: brightness(0) invert(1) !important; background-color: white !important; opacity: 1 !important; }' : ''}
            `;
        }

        buttons.forEach(cfg => {
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

            // Visibilidad y estilos
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
        updateUI();
    }

    updateUI();
    await controlMic('/status');
})();
