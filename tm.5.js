// ==UserScript==
// @name         Reloj Verde Universal PRO (Google FIX REAL)
// @namespace    http://tampermonkey.net/
// @version      3.0
// @description  Reloj que funciona en Google Calendar y Meet
// @match        https://*/*
// @grant        none
// @run-at       document-start
// @inject-into  page
// ==/UserScript==

(function() {
    'use strict';

    let isDismissed = false;

    // 1. ESTILOS (Inyectados de forma segura)
    const css = `
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

        #local-clock-panel:active { transform: scale(0.95); }

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

    const style = document.createElement('style');
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);

    // 2. LÓGICA DE ACTUALIZACIÓN (Usando textContent para evitar bloqueos)
    function updateClock() {
        const clock = document.getElementById('local-clock-panel');
        if (!clock || isDismissed) return;

        const now = new Date();

        // Hora
        let hours = now.getHours();
        const ampm = hours >= 12 ? 'pm' : 'am';
        hours = hours % 12 || 12;
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        const timeString = `${hours}:${minutes}:${seconds}${ampm}`;

        // Fecha: Martes 24 Marzo (03) 2026
        const dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
        const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

        const diaNombre = dias[now.getDay()];
        const mesNombre = meses[now.getMonth()];
        const mesNum = String(now.getMonth() + 1).padStart(2, '0');
        const dateString = `${diaNombre} ${now.getDate()} ${mesNombre} (${mesNum}) ${now.getFullYear()}`;

        const timeDiv = document.getElementById('local-clock-time');
        const dateDiv = document.getElementById('local-clock-date');

        if (timeDiv) timeDiv.textContent = timeString;
        if (dateDiv) dateDiv.textContent = dateString;
    }

    // 3. CREACIÓN SEGURA (Sin usar innerHTML)
    function createClock() {
        if (document.getElementById('local-clock-panel') || isDismissed) return;

        const clock = document.createElement('div');
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
            isDismissed = true;
            setTimeout(() => clock.remove(), 300);
        };

        // En sitios complejos como Gemini, a veces es mejor añadir al DocumentElement
        (document.body || document.documentElement).appendChild(clock);
        updateClock();
    }

    setInterval(() => {
        if (!isDismissed) {
            createClock();
            updateClock();
        }
    }, 1000);

})();