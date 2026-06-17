// ==UserScript==
// @name         Google Meet Fondo Blanco con Switch
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  Aplica fondo blanco a Google Meet con botón para activar/desactivar
// @author       Tu AI de confianza
// @match        https://meet.google.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    let fondoBlancoActivo = true;

    // Crear un estilo CSS para el fondo blanco
    const crearEstiloCSS = () => {
        const estilo = document.createElement('style');
        estilo.id = 'fondo-blanco-estilos';
        estilo.textContent = `
            /* Fondo general */
            body.fondo-blanco-activo,
            body.fondo-blanco-activo main,
            body.fondo-blanco-activo .T4LgNb,
            body.fondo-blanco-activo #yDmH0d {
                background: white !important;
                background-color: white !important;
            }

            /* Texto */
            body.fondo-blanco-activo .XEazBc,
            body.fondo-blanco-activo .notranslate {
                color: #202124 !important;
            }

            /* Cuadros de participantes */
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc,
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .FKJK2b,
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .ZrmAYe,
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .koV58,
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .LBDzPb,
            body.fondo-blanco-activo .dkjMxf.iPFm3e.MVbbRb.tSl2vc .p2hjYe {
                background: white !important;
                background-color: white !important;
            }

            /* Eliminar imágenes borrosas */
            body.fondo-blanco-activo [style*="--tile-blurred-image-url"] {
                --tile-blurred-image-url: none !important;
            }
        `;
        return estilo;
    };

    const toggleFondoBlanco = () => {
        fondoBlancoActivo = !fondoBlancoActivo;

        if (fondoBlancoActivo) {
            document.body.classList.add('fondo-blanco-activo');
            botonSwitch.textContent = '🎨 Fondo Blanco ON';
            botonSwitch.style.background = '#4CAF50';
        } else {
            document.body.classList.remove('fondo-blanco-activo');
            botonSwitch.textContent = '⬜ Fondo Blanco OFF';
            botonSwitch.style.background = '#f44336';
        }
    };

    // Crear botón flotante
    const crearBoton = () => {
        const boton = document.createElement('button');
        boton.id = 'fondo-blanco-switch';
        boton.textContent = fondoBlancoActivo ? '🎨 Fondo Blanco ON' : '⬜ Fondo Blanco OFF';
        boton.style.cssText = `
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 9999;
            padding: 10px 20px;
            background: ${fondoBlancoActivo ? '#4CAF50' : '#f44336'};
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            transition: all 0.3s ease;
        `;

        boton.addEventListener('mouseenter', () => {
            boton.style.transform = 'scale(1.05)';
        });

        boton.addEventListener('mouseleave', () => {
            boton.style.transform = 'scale(1)';
        });

        boton.addEventListener('click', toggleFondoBlanco);

        return boton;
    };

    // Inicializar
    const iniciar = () => {
        // Verificar si el botón ya existe
        if (document.getElementById('fondo-blanco-switch')) return;

        // Añadir estilos CSS
        if (!document.getElementById('fondo-blanco-estilos')) {
            document.head.appendChild(crearEstiloCSS());
        }

        // Añadir botón al DOM
        const boton = crearBoton();
        document.body.appendChild(boton);
        window.botonSwitch = boton;

        // Activar fondo blanco por defecto
        document.body.classList.add('fondo-blanco-activo');
    };

    // Esperar a que el DOM esté listo
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }

})();