// ==UserScript==
// @name         YouTube Total Whiteout - Bloqueo Visual Anti-Fatiga
// @namespace    http://tampermonkey.net/
// @version      2.0
// @description  Sustituye por completo videos, miniaturas y avatares por un recuadro blanco total.
// @author       Tu Colaborador AI
// @match        https://www.youtube.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    // Función principal que fuerza el blanco total
    function forzarBlancoTotal() {
        // Seleccionamos TODOS los elementos visuales clave
        const selectores = [
            'video',                         // El reproductor de video
            'img',                           // Miniaturas, avatares, banners
            '.ytp-videowall-still-image',    // Miniaturas finales de video
            'canvas',                        // Previsualizaciones
            '.ytp-cued-thumbnail-overlay-image', // Miniatura de carga
            'ytd-shorts-player-view-model video' // Videos de Shorts
        ];

        const elementos = document.querySelectorAll(selectores.join(','));

        elementos.forEach(el => {
            // Usamos !important en línea para máxima prioridad
            el.style.setProperty('filter', 'brightness(0) invert(1)', 'important'); // Convierte todo en blanco puro
            el.style.setProperty('background-color', 'white', 'important');
            el.style.setProperty('opacity', '1', 'important'); // Asegura que sea opaco

            // Para el elemento video, a veces es necesario forzar la opacidad del contenedor
            if (el.tagName.toLowerCase() === 'video') {
                el.style.setProperty('visibility', 'visible', 'important');
            }
        });
    }

    // Ejecutamos muy rápido (cada 100ms) para que YouTube no tenga tiempo de mostrar nada
    setInterval(forzarBlancoTotal, 100);

    // Ejecución inmediata
    forzarBlancoTotal();
})();