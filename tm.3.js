// ==UserScript==
// @name         Google Meet Varita Blanca
// @namespace    http://tampermonkey.net/
// @version      2.1
// @description  Varita mágica para ocultar videos.
// @author       Gemini (y Tú)
// @match        https://meet.google.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // ==========================================
    // 1. ESTILOS (Varita Mágica)
    // ==========================================
    const css = `
        /* Estilos de la Varita */
        .varita-cursor-activa {
            cursor: crosshair !important;
        }
        .varita-highlight {
            outline: 2px solid #4285f4 !important;
            outline-offset: -2px;
        }
    `;

    const estilo = document.createElement('style');
    estilo.textContent = css;
    (document.head || document.documentElement).appendChild(estilo);


    // ==========================================
    // 2. LÓGICA DE LA VARITA MÁGICA
    // ==========================================
    let varitaActiva = false;

    const blanquearElemento = (e) => {
        if (!varitaActiva) return;

        e.preventDefault();
        e.stopPropagation();

        const el = e.target;

        // Blanqueo
        el.style.setProperty('background', 'white', 'important');
        el.style.setProperty('background-color', 'white', 'important');
        el.style.setProperty('color', '#202124', 'important');

        // Ocultar video directo
        if (el.tagName === 'VIDEO') {
            el.style.setProperty('display', 'none', 'important');
        }

        // Ocultar videos internos
        const videosInternos = el.querySelectorAll('video');
        videosInternos.forEach(v => {
            v.style.setProperty('display', 'none', 'important');
        });

        // Ocultar canvas
        const canvasInternos = el.querySelectorAll('canvas');
        canvasInternos.forEach(c => {
            c.style.setProperty('opacity', '0', 'important');
        });

        desactivarModoVarita();
    };

    const activarModoVarita = () => {
        varitaActiva = true;
        document.body.classList.add('varita-cursor-activa');
        window.botonVarita.textContent = '🪄 Varita: LISTO';
        window.botonVarita.style.background = '#fbbc04';
        document.addEventListener('click', blanquearElemento, { capture: true, once: true });
    };

    const desactivarModoVarita = () => {
        varitaActiva = false;
        document.body.classList.remove('varita-cursor-activa');
        window.botonVarita.textContent = '🪄 Varita Mágica';
        window.botonVarita.style.background = '#5f6368';
    };

    const crearBotonVarita = () => {
        if (document.getElementById('varita-magica-btn')) return;
        const boton = document.createElement('button');
        boton.id = 'varita-magica-btn';
        boton.textContent = '🪄 Varita Mágica';
        boton.style.cssText = `
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

        boton.addEventListener('click', (e) => {
            e.stopPropagation();
            if (!varitaActiva) activarModoVarita();
            else desactivarModoVarita();
        });

        document.body.appendChild(boton);
        window.botonVarita = boton;
    };


    function ensureUIExists() {
        // Asegurar que exista la Varita
        crearBotonVarita();
    }

    // ==========================================
    // 4. INICIALIZACIÓN Y PROTECCIÓN
    // ==========================================
    const iniciar = () => {
        ensureUIExists();
        setInterval(ensureUIExists, 1000); // Vigila que no se borren
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }

    // Observador extremo por si Meet recarga la interfaz bruscamente
    const observer = new MutationObserver(() => {
        if (!document.getElementById('varita-magica-btn')) {
            ensureUIExists();
        }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });

})();