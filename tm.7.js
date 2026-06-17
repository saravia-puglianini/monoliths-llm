// ==UserScript==
// @name         Google Meet Opener Auto
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Abre reuniones de Google Meet automáticamente en el rango de tiempo permitido.
// @match        https://meet.google.com/*
// @grant        none
// ==/UserScript==
(function() {
    'use strict';
    // Registro para evitar abrir la misma reunión múltiples veces en el mismo rango de tiempo
    const reunionesAbiertas = new Set();
    // Función auxiliar para parsear texto de hora (ej: "12:30 p.m." o "6:00 p.m.") a objeto Date
    function parsearHoraReunion(horaStr) {
        const limpia = horaStr.replace(/[\u202f\u00a0]/g, ' ').trim().toLowerCase(); // Normaliza espacios sutiles
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
    // Intervalo principal de 5 segundos
    setInterval(() => {
        const divsConAriaLabel = document.querySelectorAll('div[aria-label]');
        const ahora = new Date();
        divsConAriaLabel.forEach((div) => {
            // Filtrar solo los que contienen el formato de evento "De [Hora] a ..."
            if (ariaLabel && ariaLabel.startsWith('De ')) {
                // Extraer la primera hora encontrada (Hora de inicio)
                const matchHora = ariaLabel.match(/^De\s+([0-9]{1,2}:[0-9]{2}\s*[a|p]\.m\.)/i);
                if (matchHora) {
                    const textoHoraOriginal = matchHora[1]; // Guardamos el texto exacto para buscar el div luego
                    const horaReunion = parsearHoraReunion(textoHoraOriginal);
                    if (horaReunion) {
                        // Calcular la diferencia en minutos (Actual - Reunión)
                        const diferenciaMinutos = (ahora - horaReunion) / 60000;
                        // Condición: 5 minutos antes (-5) hasta 15 minutos después (+15)
                        if (diferenciaMinutos >= -5 && diferenciaMinutos <= 15) {
                            // Buscar el div hijo que contiene exactamente ese texto de hora
                            const divHijo = Array.from(document.querySelectorAll('div'))
                                  .find(d => d.textContent.replace(/[\u202f\u00a0]/g, ' ').trim() === textoHoraOriginal.replace(/[\u202f\u00a0]/g, ' ').trim());
                            if (divHijo) {
                                const divPadre = divHijo.parentElement;
                                if (divPadre) {
                                    const callId = divPadre.getAttribute('data-call-id');
                                    // Si tiene ID de llamada y NO se ha abierto antes en esta sesión
                                    if (callId && !reunionesAbiertas.has(callId)) {
                                        const urlMeet = https://meet.google.com/${callId}?authuser=1;
                                        const opcionesPopup = "width=800,height=600,scrollbars=yes,resizable=yes";
                                        console.log([Auto-Open] Rango válido detectado (${Math.round(diferenciaMinutos)} min). Abriendo Meet: ${urlMeet});
                                        // Crear el mensaje con el texto deseado
                                        const mensaje = new SpeechSynthesisUtterance('Ingresando automáticamente a una llamada.');
                                        // Opcional: Configurar idioma
                                        mensaje.lang = 'es-ES';
                                        // Reproducir
                                        window.speechSynthesis.speak(mensaje);
                                        // Crear el mensaje con el texto deseado
                                        const mensaje = new SpeechSynthesisUtterance('repito.');
                                        // Opcional: Configurar idioma
                                        mensaje.lang = 'es-ES';
                                        // Reproducir
                                        window.speechSynthesis.speak(mensaje);
                                        // Crear el mensaje con el texto deseado
                                        const mensaje = new SpeechSynthesisUtterance('Ingresando automáticamente a una llamada.');
                                        // Opcional: Configurar idioma
                                        mensaje.lang = 'es-ES';
                                        // Reproducir
                                        window.speechSynthesis.speak(mensaje);
                                        const ahora = new Date();
                                        const horas24 = ahora.getHours();
                                        const minutos = ahora.getMinutes().toString().padStart(2, '0');
                                        // Convertir a formato de 12 horas
                                        let horas12 = horas24 % 12;
                                        horas12 = horas12 === 0 ? 12 : horas12; // Si es 0, son las 12
                                        // Determinar el período del día en texto
                                        let periodo = "";
                                        if (horas24 >= 6 && horas24 < 12) {
                                            periodo = "de la mañana";
                                        } else if (horas24 >= 12 && horas24 < 20) {
                                            periodo = "de la tarde";
                                        } else {
                                            periodo = "de la noche"; // Entre las 20:00 y las 05:59
                                        }
                                        // Construir el texto final
                                        const textoHora = `Son las ${horas12} y ${minutos} ${periodo}`;
                                        const mensaje = new SpeechSynthesisUtterance(`${textoHora}. Ingresando automáticamente a una llamada.`);
                                        // Configurar idioma y reproducir
                                        mensaje.lang = 'es-ES';
                                        window.speechSynthesis.speak(mensaje);
                                        window.open(urlMeet, "GoogleMeetPopup", opcionesPopup);
                                        // Registrar para no duplicar la apertura
                                        reunionesAbiertas.add(callId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
    }, 5000);
})();