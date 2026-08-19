# Monoliths LLM Workspace

Repositorio de utilidades, automatizaciones del sistema y arquitectura de audio modular bajo demanda.

---

# 🎧 Sistema de Audio Modular Bajo Demanda y Plan de Pruebas QA

Sistema de audio optimizado para **mínimo consumo de recursos en el sistema**:
- **Arranque en Frío:** Cero servicios de audio en OpenRC y lista negra de módulos en modprobe (`/etc/modprobe.d/blacklist-audio.conf`).
- **Módulos Bajo Demanda:** Cada comando carga únicamente los módulos del kernel requeridos (`snd_sof_*`, `snd-usb-audio`, `snd-aloop`).
- **Auto-Apagado Dinámico:** Gestionado mediante `/tmp/.apagar_esto_para_encender_el_siguiente`, descargando con `modprobe -r` y deteniendo procesos previos que no se utilicen en el nuevo perfil.
- **Configuración ALSA Centralizada:** Generación atómica en `~/.asoundrc` (eliminando `/etc/asound.conf`).

---

## 🎛️ Matriz de Scripts y Perfiles de Audio

| Script | Salida (Playback) | Entrada (Capture) | Loopback / Monitoreo | Filtro DSP | Log |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`OUT=sof-snd-dsp-IN=sof-snd-dsp.sh`** | Altavoces Laptop SOF | Mic Laptop SOF | Ninguno | Directo | `/tmp/out_sof_in_sof.log` |
| **`OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh`** | Altavoces Laptop SOF | Mic Laptop SOF | Ninguno | Filtro Anti-Ruido | `/tmp/out_sof_in_sof_filter.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh`** | Auriculares JBL | Micrófono JBL | Ninguno | Directo | `/tmp/out_jbl_in_jbl.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh`** | Auriculares JBL | Micrófono JBL | Ninguno | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh`** | Auriculares JBL | Micrófono JBL | Mic JBL $\rightarrow$ JBL (~0.5ms) | Directo | `/tmp/out_jbl_in_jbl_loopback_jbl.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh`** | Auriculares JBL | Micrófono JBL | Mic JBL $\rightarrow$ JBL (~0.5ms) | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter_loopback_jbl.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh`** | Auriculares JBL | Mic JBL / SOF | Mic Laptop $\rightarrow$ JBL (~0.5ms) | Directo | `/tmp/out_jbl_in_jbl_loopback_sof.log` |
| **`OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh`** | Auriculares JBL | Mic JBL / SOF | Mic Laptop $\rightarrow$ JBL (~0.5ms) | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter_loopback_sof.log` |

---

## 🧪 Plan de Pruebas QA (Matriz de Casos de Prueba)

Ejecuta la suite interactiva gráfica en cualquier momento con:
```bash
/home/user/monoliths-llm/qa_audio_test_plan.sh
```

### Casos de Prueba Detallados:

| ID | Perfil a Probar | Validación Técnica (Automática) | Validación Auditiva (Tu Oído con YAD) | Criterio de Éxito |
| :--- | :--- | :--- | :--- | :--- |
| **TC-01** | `OUT=sof-snd-dsp-IN=sof-snd-dsp.sh` | • Módulos SOF cargados<br>• `snd-aloop` descargado<br>• `sofhdadsp` en `/proc/asound/cards` | • Tono de 520Hz por parlantes internos<br>• Grabación y reproducción de voz (3s) | Escuchas el tono y tu voz por los altavoces de la laptop. |
| **TC-02** | `OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh` | • Pipeline generado en `/tmp/jbl_pipeline`<br>• Alias ALSA `dsnoop_mic` configurado | • Tono de prueba por parlantes de la laptop | Confirmas que el perfil SOF filtrado está activo. |
| **TC-03** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh` | • `snd-usb-audio` cargado<br>• Módulos SOF descargados<br>• `snd-aloop` descargado | • Tono de 440Hz en auriculares JBL<br>• Grabación y reproducción de voz (3s) | Escuchas en los audífonos JBL y nada por la laptop. |
| **TC-04** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh` | • `snd-usb-audio` cargado<br>• Pipeline anti-ruido configurado | • Tono de prueba en auriculares JBL | Confirmas que el perfil JBL filtrado está activo. |
| **TC-05** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh` | • `snd-usb-audio` y `snd-aloop` cargados<br>• Proceso `gst-launch-1.0` activo | • Habla por el micrófono JBL en tiempo real | Te escuchas en los auriculares JBL con latencia ultra-baja (~0.5ms). |
| **TC-06** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh` | • Pipeline con `audiocheblimit` y `audiodynamic` activo en `gst-launch-1.0` | • Habla por el micrófono JBL y haz ruido de fondo suave | Tu voz se escucha clara y el ruido de fondo (tecleo, respiración) se atenúa. |
| **TC-07** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh` | • `snd-usb-audio`, `snd-aloop` y módulos SOF activos<br>• Altavoces laptop silenciados | • Habla o da golpecitos cerca del micrófono de la laptop | Escuchas el micrófono de la laptop en tus auriculares JBL. |
| **TC-08** | `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh` | • `gst-launch-1.0` filtrando captura de laptop hacia sink JBL | • Habla hacia el micrófono de la laptop con ruido ambiente | Escuchas el micrófono de la laptop en tus JBL con filtro anti-ruido activo. |

---

## 💬 Guía de Validación Conjunta (Prompts de Prueba)

Puedes lanzar cualquiera de estos prompts para validar juntos una prueba específica o el estado del sistema:

* **Para ejecutar una prueba técnica y pedir tu confirmación:**
  > *"Ejecuta la prueba TC-05 de Loopback JBL y valida si los procesos y módulos están correctos."*

* **Para verificar el apagado de módulos al cambiar de perfil:**
  > *"Cambia de SOF a JBL Directo y muéstrame el contenido de `/tmp/.apagar_esto_para_encender_el_siguiente` y `lsmod`."*

* **Para auditar los logs tras una prueba:**
  > *"Revisa los logs en `/tmp/qa_audio_report.txt` y `/tmp/out_jbl_in_jbl_filter_loopback_sof.log` y dime el diagnóstico."*

---

# 📋 Sistema de Recordatorios Automatizados (Jira & Ops360)

Este repositorio también contiene un sistema interactivo de alertas diseñado para asegurar el registro diario de horas de trabajo en **Jira** (Atlassian) y los marcajes de asistencia (toques) en **Ops360 Entelgy**. 

Las alertas se muestran visualmente a través de ventanas de diálogo interactivas en el escritorio y cuentan con sincronización automática mediante API.

## Componentes del Sistema

1. **`jira-reminder.sh`**: Monitorea las horas laborales pendientes de registro en el día actual (9:00 AM a 6:00 PM).
2. **`ops360-reminder.sh`**: Enfocado en los 4 toques obligatorios de la jornada laboral en Entelgy.
3. **`run-reminders.sh`**: Despachador para entornos de Crontab.
4. **`ver-horas.sh`**: Visualización en tabla interactiva de las últimas 50 entradas.
5. **`jira_helper.py`**: Interacción con la API de Atlassian Jira.