// ==UserScript==
// @name         Reloj Verde Localhost + Mes Numérico (Click para Cerrar)
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  Reloj verde para localhost con formato de mes "Nombre (00)". Se cierra al clickear.
// @author       Gemini
// @match        http://localhost/*
// @match        http://127.0.0.1/*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    let isDismissed = false;

    // 1. ESTILOS
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
            min-width: 200px !important;
            font-family: 'Segoe UI', Arial, sans-serif !important;
            cursor: pointer !important;
            user-select: none !important;
            transition: opacity 0.3s ease, transform 0.2s ease !important;
        }

        #local-clock-panel:active {
            transform: scale(0.95) !important;
        }

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

    // 2. LÓGICA DEL TIEMPO
    function updateClock() {
        const clock = document.getElementById('local-clock-panel');
        if (!clock || isDismissed) return;

        const now = new Date();

        // Hora: 4:05:12pm
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
        const diaNum = now.getDate();
        const mesNombre = meses[now.getMonth()];
        const mesNum = String(now.getMonth() + 1).padStart(2, '0'); // Número del mes con cero inicial
        const año = now.getFullYear();

        const dateString = `${diaNombre} ${diaNum} ${mesNombre} (${mesNum}) ${año}`;

        const timeDiv = document.getElementById('local-clock-time');
        const dateDiv = document.getElementById('local-clock-date');

        if (timeDiv) timeDiv.textContent = timeString;
        if (dateDiv) dateDiv.textContent = dateString;
    }

    // 3. INICIALIZACIÓN
    function initClock() {
        if (document.getElementById('local-clock-panel') || isDismissed) return;

        const clock = document.createElement('div');
        clock.id = 'local-clock-panel';
        clock.title = "Click para cerrar";

        clock.innerHTML = `
            <div id="local-clock-time"></div>
            <div id="local-clock-date"></div>
        `;

        // Cerrar al hacer clic
        clock.onclick = () => {
            clock.style.opacity = '0';
            isDismissed = true;
            setTimeout(() => clock.remove(), 300);
        };

        document.body.appendChild(clock);
        updateClock();
    }

    // Ejecución cada segundo
    setInterval(() => {
        if (!isDismissed) {
            initClock();
            updateClock();
        }
    }, 1000);

})();