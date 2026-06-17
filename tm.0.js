// ==UserScript==
// @name         Gmail Reloj Verde Flotante
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Añade el reloj verde con segundos en la esquina superior derecha de Gmail.
// @author       Gemini
// @match        https://mail.google.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    // 1. ESTILOS DEL RELOJ (Solo el panel verde, sin blanquear la pantalla)
    const css = `
        /* Panel Verde Claro */
        #custom-gmail-clock {
            position: fixed !important;
            top: 80px !important; /* Un poco más abajo para no tapar la barra de búsqueda de Gmail */
            right: 25px !important;
            background-color: #90ee90 !important;
            padding: 12px 20px !important;
            border-radius: 10px !important;
            box-shadow: 0 4px 15px rgba(0,0,0,0.3) !important;
            z-index: 2147483647 !important;
            pointer-events: none !important; /* Permite hacer clic a los botones que estén debajo */
            display: flex !important;
            flex-direction: column !important;
            align-items: flex-end !important;
            border: 2px solid #2e7d32 !important;
            min-width: 200px !important;
            font-family: Arial, sans-serif !important;
        }

        /* Forzar color negro en los textos del reloj */
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

    const style = document.createElement('style');
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);

    // 2. LÓGICA DEL RELOJ (Bypaseando la seguridad de Google)
    function updateClock() {
        const clock = document.getElementById('custom-gmail-clock');
        if (!clock) return;

        const now = new Date();

        // HORA (ej. 9:03:45am)
        let hours = now.getHours();
        const ampm = hours >= 12 ? 'pm' : 'am';
        hours = hours % 12 || 12;
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        const timeString = `${hours}:${minutes}:${seconds}${ampm}`;

        // FECHA (ej. Martes 24 Marzo (03) 2026)
        const dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
        const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

        const diaNombre = dias[now.getDay()];
        const diaNum = now.getDate();
        const mesNombre = meses[now.getMonth()];
        const mesNum = String(now.getMonth() + 1).padStart(2, '0');
        const año = now.getFullYear();

        const dateString = `${diaNombre} ${diaNum} ${mesNombre} (${mesNum}) ${año}`;

        // Buscamos o creamos los elementos de texto de forma segura
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

        // Asignamos el texto directamente
        timeDiv.textContent = timeString;
        dateDiv.textContent = dateString;
    }

    function ensureClockExists() {
        if (!document.getElementById('custom-gmail-clock')) {
            const clock = document.createElement('div');
            clock.id = 'custom-gmail-clock';
            document.body.appendChild(clock);
        }
        updateClock();
    }

    // Actualizar cada segundo
    setInterval(ensureClockExists, 1000);

    // Vigilar si Gmail recarga la interfaz
    const observer = new MutationObserver(() => {
        if (!document.getElementById('custom-gmail-clock')) {
            ensureClockExists();
        }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });

})();