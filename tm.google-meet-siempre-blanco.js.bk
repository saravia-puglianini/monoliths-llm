// ==UserScript==
// @name         Google Meet Fondo Blanco
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Aplica un fondo blanco a la interfaz de Google Meet.
// @author       Tu AI de confianza
// @match        https://meet.google.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // --- LÓGICA DEL FONDO BLANCO ---
    const aplicarBlanco = () => {
        const selectoresFondo = [
            document.body,
            document.querySelector('main'),
            document.querySelector('.T4LgNb'),
            document.getElementById('yDmH0d')
        ];

        selectoresFondo.forEach(el => {
            if (el) {
                el.style.setProperty('background', 'white', 'important');
                el.style.setProperty('background-color', 'white', 'important');
            }
        });

        document.querySelectorAll('.XEazBc, .notranslate').forEach(texto => {
            texto.style.color = '#202124';
        });
    };

    setTimeout(aplicarBlanco, 3000);
    setInterval(aplicarBlanco, 5000);

})();