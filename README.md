# 🚀 Monoliths LLM & System Services Workspace

Guía integral y manual de replicación/despliegue para configurar todos los servicios, utilidades del sistema, perfiles de audio bajo demanda, demonios web, cliente gráfico Xpra HTML5 y binarios ensamblador desarrollados en esta estación de trabajo hacia otra máquina.

---

## 📑 Tabla de Contenidos
1. [Requisitos Previos y Dependencias del Sistema](#1-requisitos-previos-y-dependencias-del-sistema)
2. [Estructura de Directorios y Rutas Clave](#2-estructura-de-directorios-y-rutas-clave)
3. [Servicios y Paneles Web Locales](#3-servicios-y-paneles-web-locales)
   - [A. `registro-diario-broadway` (Puerto 8085)](#a-registro-diario-broadway-puerto-8085)
   - [B. `my-shell-9097-service` (Puerto 9097)](#b-my-shell-9097-service-puerto-9097)
   - [C. `amd64gnu+linux-9099-service` (Puerto 9099)](#c-amd64gnulinux-9099-service-puerto-9099)
   - [D. Implementación y Servidor Xpra HTML5 (Acceso Gráfico Remoto)](#d-implementación-y-servidor-xpra-html5-acceso-gráfico-remoto)
4. [Extensiones de Navegador](#4-extensiones-de-navegador)
   - [Extensión `horas-persistent-extension`](#extensión-horas-persistent-extension)
5. [Binarios Optimizados en Ensamblador y C (x86_64)](#5-binarios-optimizados-en-ensamblador-y-c-x86_64)
6. [Sistema de Audio Modular Bajo Demanda y Plan QA](#6-sistema-de-audio-modular-bajo-demanda-y-plan-qa)
7. [Sistema de Alertas y Notificaciones (Jira & Ops360)](#7-sistema-de-alertas-y-notificaciones-jira--ops360)
8. [Configuración de Inicio de Sesión Gráfica (`.xinitrc` / `xprofile`)](#8-configuración-de-inicio-de-sesión-gráfica-xinitrc--xprofile)
9. [Script de Configuración Rápida en Máquina Nueva](#9-script-de-configuración-rápida-en-máquina-nueva)

---

## 1. Requisitos Previos y Dependencias del Sistema

### Paquetes Base (Alpine / Gentoo / Debian / Ubuntu / OpenRC):
- **Intérprete / Lenguajes:** `python3`, `python3-gobject`, `gtk+3.0`, `broadwayd` (GDK Broadway backend), `gcc`, `make`, `dash` o `bash`.
- **Librerías X11 y Gráficas:** `libX11`, `libX11-devel` / `libx11-dev`, `libXi-devel` / `libxi-dev`, `libxosd-devel` / `libxosd-dev`, `feh`, `scrot`, `xterm`, `yad` (o `PyYad`).
- **Audio y Multimedia:** `alsa-utils`, `mpv`, `gstreamer`, `gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `pulseaudio-utils` (o ALSA puro con `snd-aloop`), `piper` (TTS neuronal).
- **Acceso Remoto / Xpra:** `xpra` (servidor de display virtual / puente WebSocket).
- **Gestor de Inicio:** OpenRC (o adaptar los scripts de `/etc/init.d/` a systemd si la máquina destino usa systemd).

---

## 2. Estructura de Directorios y Rutas Clave

Para garantizar que todos los servicios y scripts funcionen sin modificaciones de rutas:

```
/home/user/
├── monoliths-llm/                  # Repositorio principal de automatizaciones, audio y Broadway
│   ├── registro-diario.py          # UI Registro Diario (GTK3 estándar / X11)
│   ├── registro-diario-broadwayd.py# UI Registro Diario adaptada a GDK Broadway
│   ├── registro-diario-broadway-daemon.py # Daemon supervisor Broadway
│   ├── registro-diario-broadway.openrc   # Script OpenRC
│   ├── horas-persistent-extension/ # Extensión Chrome para horario laboral
│   ├── Makefile.asm                # Compilador de binarios x86_64
│   └── OUT=*.sh                    # Scripts de perfiles de audio modular
├── monoliths-hm/                   # Repositorio de entorno de usuario, X11, my.shell y Xpra
│   ├── xpra-html5/                 # Cliente web Xpra HTML5 completo
│   ├── bin/                        # Binarios compilados OSD y control de hardware
│   ├── src/                        # Fuentes C y ASM de binarios OSD
│   ├── Makefile                    # Compilador de utilidades OSD / ASM
│   ├── xinitrc / xprofile          # Inicialización de sesión gráfica
│   └── my.shell.sh                 # Orquestador maestro de scripts del sistema
├── amd64gnu+linux/                 # Repositorio de scripts de despliegue / frontend
├── .local/
│   ├── lib/
│   │   ├── my-shell-9097/          # Backend panel web 9097 (my_shell_9097.py)
│   │   └── assembly-dispatch-9099/ # Backend panel web 9099 (assembly_dispatch_9099.py)
│   └── state/                      # Logs, bases de datos y estados de tareas
```

---

## 3. Servicios y Paneles Web Locales

### A. `registro-diario-broadway` (Puerto 8085)
- **Propósito:** Interfaz gráfica web persistente (GTK3 vía Broadway) para el control y justificación de actividades diarias, exportación a Jira y generación de reportes PDF.
- **Archivos:**
  - `registro-diario-broadwayd.py`: Aplicación GTK3 con bindings PyGObject en backend Broadway.
  - `registro-diario-broadway-daemon.py`: Supervisor que levanta `broadwayd --port=8085 :5` y mantiene vivo el proceso de la app.
  - `registro-diario-broadway.openrc`: Servicio init.d.
- **Instalación:**
  ```bash
  sudo cp /home/user/monoliths-llm/registro-diario-broadway.openrc /etc/init.d/registro-diario-broadway
  sudo chmod +x /etc/init.d/registro-diario-broadway
  sudo rc-update add registro-diario-broadway default
  sudo rc-service registro-diario-broadway start
  ```
- **Acceso:** Abrir en navegador `http://127.0.0.1:8085`

---

### B. `my-shell-9097-service` (Puerto 9097)
- **Propósito:** Panel web interactivo y concurrente que expone el menú de tareas y scripts de `my.shell.sh` con streaming de logs en tiempo real vía WebSocket / polling.
- **Archivos:**
  - `/home/user/.local/lib/my-shell-9097/my_shell_9097.py`
  - `/etc/init.d/my-shell-9097-service`
- **Instalación:**
  ```bash
  sudo cp /home/user/.local/lib/my-shell-9097/my-shell-9097-service.initd /etc/init.d/my-shell-9097-service
  sudo chmod +x /etc/init.d/my-shell-9097-service
  sudo rc-update add my-shell-9097-service default
  sudo rc-service my-shell-9097-service start
  ```
- **Acceso:** `http://127.0.0.1:9097`

---

### C. `amd64gnu+linux-9099-service` (Puerto 9099)
- **Propósito:** Panel web local para despachar y ejecutar tareas, scripts de despliegue y herramientas del directorio `~/amd64gnu+linux/`.
- **Archivos:**
  - `/home/user/.local/lib/assembly-dispatch-9099/assembly_dispatch_9099.py`
  - `/etc/init.d/amd64gnu+linux-9099-service`
- **Instalación:**
  ```bash
  sudo cp /home/user/.local/lib/assembly-dispatch-9099/amd64gnu+linux-9099-service.initd /etc/init.d/amd64gnu+linux-9099-service
  sudo chmod +x /etc/init.d/amd64gnu+linux-9099-service
  sudo rc-update add amd64gnu+linux-9099-service default
  sudo rc-service amd64gnu+linux-9099-service start
  ```
- **Acceso:** `http://127.0.0.1:9099`

---

### D. Implementación y Servidor Xpra HTML5 (Acceso Gráfico Remoto)
- **Ubicación:** `/home/user/monoliths-hm/xpra-html5/`
- **Arquitectura:**
  - **Cliente Web Puro (HTML5/JavaScript):** Implementación completa con decodificador H.264 Broadway (`broadway/Decoder.js`), descompresión Brotli/LZ4/Zlib, motor de audio Aurora (AAC/MP3/FLAC), aceleración por Web Workers y soporte de teclado/keycodes internacionales (`js/Keycodes.js`).
  - **Gestor de Ventanas Flotante:** Soporte para mover, minimizar y maximizar ventanas individuales remotas en el navegador mediante `js/Menu-custom.js` y `js/Window.js`.
  - **Archivos pre-comprimidos:** Contiene versiones `.br` y `.gz` para servir estáticos a alta velocidad y bajo consumo de CPU.
- **Puesta en Marcha:**
  1. **Opción A: Servidor integrado con el demonio Xpra (WebSocket nativo):**
     ```bash
     xpra start :100 --bind-ws=0.0.0.0:10000 --html=/home/user/monoliths-hm/xpra-html5/ --daemon=yes --start-child=openbox
     ```
  2. **Opción B: Servidor HTTP local independiente para testing / debugging:**
     ```bash
     cd /home/user/monoliths-hm/xpra-html5
     python3 -m http.server 8081
     ```
  3. **Conexión:**
     Abrir en el navegador cliente: `http://<ip-servidor>:10000/index.html` o `http://localhost:8081`.

---

## 4. Extensiones de Navegador

### Extensión `horas-persistent-extension`
- **Ubicación:** `~/monoliths-llm/horas-persistent-extension`
- **Función:**
  - Mantiene abierta la pestaña de `http://localhost:8085` de lunes a viernes en segundo plano.
  - Sincroniza estado de justificación con Jira Atlassian.
- **Instalación en Chromium / Chrome / Brave:**
  1. Ir a `chrome://extensions/`
  2. Activar **Modo de desarrollador** (Developer mode).
  3. Hacer clic en **Cargar descomprimida** (Load unpacked).
  4. Seleccionar la carpeta `/home/user/monoliths-llm/horas-persistent-extension`.

---

## 5. Binarios Optimizados en Ensamblador y C (x86_64)

### A. Binarios de `monoliths-llm`:
| Binario | Fuente | Descripción |
| :--- | :--- | :--- |
| `alt_tab_maximize_emacs_asm` | `alt_tab_maximize_emacs.s` | Gestor y maximizador instantáneo de ventanas Emacs / X11 vía Xlib directo. |
| `hotkey_listener_asm` | `hotkey_listener_asm.s` | Listener global de atajos de teclado de bajísimo consumo. |
| `ram_report_asm` | `ram_report_asm.s` | Lector de `/proc/meminfo` y métricas de RAM en ASM puro. |
| `bat_asm` | `bat_asm.s` | Monitor de batería y consumo de energía en ASM. |
| `timer_asm` | `timer_asm.s` | Contador de tiempo de precisión. |

### B. Binarios de `monoliths-hm` (`bin/`):
| Binario | Fuente | Librerías / Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| `bin/clock_osd` | `src/clock_osd.c` / `.s` | `-lxosd -lX11 -lpthread` | Reloj flotante transparente sobre X11. |
| `bin/hour_counter_osd` | `src/hour_counter_osd.c` / `.s` | `-lxosd -lX11 -lpthread` | Contador regresivo visual de horas. |
| `bin/trackball_calibrator`| `src/trackball_calibrator.c` / `.s`| `-lX11 -lXi` | Calibrador de ejes XInput de mouse/trackball. |
| `bin/personal_osdx` | `src/personal_osdx.c` / `.s` | `-lxosd -lX11` | OSD flotante de estado de batería, RAM y hora. |
| `bin/check_usb_mouse_bt_optimizer` | `src/check_usb_mouse_bt_optimizer.s` | `-nostdlib -static` | Optimizador de polling rate USB/BT en ASM puro. |
| `bin/jbl_mic_loop` | `src/jbl_mic_loop.s` | `-nostdlib -static` | Bucle de audio ultra rápido para JBL. |
| `bin/jbl_mic_set` | `src/jbl_mic_set.s` | `-nostdlib -static` | Controlador de ganancia de micrófono JBL. |
| `bin/second_counter` | `src/second_counter.s` | `-nostdlib -static` | Contador de segundos en ASM sin libc. |
| `bin/volume_ctrl` | `src/volume_ctrl.c` / `.s` | GCC C | Control de volumen por software. |
| `bin/change_brightness` | `src/change_brightness.c` / `.s` | GCC C | Regulador de brillo de pantalla. |
| `bin/play_pause_mpris` | `src/play_pause_mpris.c` / `.s` | GCC C | Control MPRIS/D-Bus de reproductores. |

### Compilación completa de ambos repositorios:
```bash
# 1. En monoliths-llm:
cd /home/user/monoliths-llm
make -f Makefile.asm
gcc -no-pie -s hotkey_listener_asm.s -lX11 -o hotkey_listener_asm
gcc -nostdlib -static -s ram_report_asm.s -o ram_report_asm
gcc -nostdlib -static -s bat_asm.s -o bat_asm
gcc -nostdlib -static -s timer_asm.s -o timer_asm

# 2. En monoliths-hm:
cd /home/user/monoliths-hm
make clean
make all
```

---

## 6. Sistema de Audio Modular Bajo Demanda y Plan QA

Arquitectura para evitar procesos de audio persistentes en segundo plano y levantar hardware ALSA/GStreamer solo cuando se necesita.

### Perfiles Principales:
| Script | Salida (Playback) | Entrada (Capture) | Loopback / Monitoreo | Filtro DSP | Log |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `OUT=sof-snd-dsp-IN=sof-snd-dsp.sh` | Altavoces Laptop SOF | Mic Laptop SOF | Ninguno | Directo | `/tmp/out_sof_in_sof.log` |
| `OUT=sof-snd-dsp-IN=sof-snd-dsp-IN-FILTER.sh` | Altavoces Laptop SOF | Mic Laptop SOF | Ninguno | Filtro Anti-Ruido | `/tmp/out_sof_in_sof_filter.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless.sh` | Auriculares JBL | Micrófono JBL | Ninguno | Directo | `/tmp/out_jbl_in_jbl.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER.sh` | Auriculares JBL | Micrófono JBL | Ninguno | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless.sh` | Auriculares JBL | Micrófono JBL | Mic JBL $\rightarrow$ JBL (~0.5ms) | Directo | `/tmp/out_jbl_in_jbl_loopback_jbl.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless.sh` | Auriculares JBL | Micrófono JBL | Mic JBL $\rightarrow$ JBL (~0.5ms) | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter_loopback_jbl.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh` | Auriculares JBL | Mic JBL / SOF | Mic Laptop $\rightarrow$ JBL (~0.5ms) | Directo | `/tmp/out_jbl_in_jbl_loopback_sof.log` |
| `OUT=jbl-usb-wireless-IN=jbl-usb-wireless-FILTER-LOOPBACK=jbl-usb-wireless+IN=sof-snd-dsp.sh` | Auriculares JBL | Mic JBL / SOF | Mic Laptop $\rightarrow$ JBL (~0.5ms) | Filtro Anti-Ruido | `/tmp/out_jbl_in_jbl_filter_loopback_sof.log` |

### Suite de Pruebas QA:
Ejecuta la suite interactiva gráfica en cualquier momento con:
```bash
/home/user/monoliths-llm/qa_audio_test_plan.sh
```

---

## 7. Sistema de Alertas y Notificaciones (Jira & Ops360)

Recordatorios interactivos en el escritorio para asegurar el registro diario y toques obligatorios.

- **`jira-reminder.sh`**: Notifica horas faltantes de registro en Jira (9:00 AM - 6:00 PM).
- **`ops360-reminder.sh`**: Valida los 4 toques de asistencia obligatorios.
- **`run-reminders.sh`**: Despachador para cron / timers.
- **`ver-horas.sh`**: Visualizador tabular rápido de las últimas 50 entradas.
- **`jira_helper.py`**: Cliente de conexión contra la API de Atlassian.

---

## 8. Configuración de Inicio de Sesión Gráfica (`.xinitrc` / `xprofile`)

Para configurar la sesión gráfica X11 completa en la máquina nueva:
```bash
ln -sf /home/user/monoliths-hm/xinitrc /home/user/.xinitrc
ln -sf /home/user/monoliths-hm/xprofile /home/user/.xprofile
```

---

## 9. Script de Configuración Rápida en Máquina Nueva

Copia y ejecuta estos comandos en la terminal de la nueva máquina tras clonar los repositorios:

```bash
#!/bin/bash
set -e

echo "=== 1. Configurando directorios locales y enlaces simbólicos de servicios ==="
mkdir -p /home/user/.local/lib
mkdir -p /home/user/.local/state/assembly-dispatch-9099
mkdir -p /home/user/.local/state/my-shell-9097
mkdir -p /home/user/.justificar

# Enlaces simbólicos de servicios hacia monoliths-llm (repositorio central)
ln -sfn /home/user/monoliths-llm/services/my-shell-9097 /home/user/.local/lib/my-shell-9097
ln -sfn /home/user/monoliths-llm/services/assembly-dispatch-9099 /home/user/.local/lib/assembly-dispatch-9099

echo "=== 2. Enlaces simbólicos de sesión X11 ==="
ln -sf /home/user/monoliths-hm/xinitrc /home/user/.xinitrc
ln -sf /home/user/monoliths-hm/xprofile /home/user/.xprofile

echo "=== 3. Compilando binarios de monoliths-hm ==="
cd /home/user/monoliths-hm
make clean && make all

echo "=== 4. Compilando utilidades ASM de monoliths-llm ==="
cd /home/user/monoliths-llm
make -f Makefile.asm || true
gcc -no-pie -s hotkey_listener_asm.s -lX11 -o hotkey_listener_asm || true
gcc -nostdlib -static -s ram_report_asm.s -o ram_report_asm || true
gcc -nostdlib -static -s bat_asm.s -o bat_asm || true
gcc -nostdlib -static -s timer_asm.s -o timer_asm || true

echo "=== 5. Instalando servicios (OpenRC / systemd) ==="
if [ -d "/etc/init.d" ]; then
    # Registro Diario Broadway (8085)
    sudo cp /home/user/monoliths-llm/registro-diario-broadway.openrc /etc/init.d/registro-diario-broadway
    sudo chmod +x /etc/init.d/registro-diario-broadway
    sudo rc-update add registro-diario-broadway default

    # Panel My Shell 9097
    if [ -f "/home/user/.local/lib/my-shell-9097/my-shell-9097-service.initd" ]; then
        sudo cp /home/user/.local/lib/my-shell-9097/my-shell-9097-service.initd /etc/init.d/my-shell-9097-service
        sudo chmod +x /etc/init.d/my-shell-9097-service
        sudo rc-update add my-shell-9097-service default
    fi

    # Panel Assembly Dispatch 9099
    if [ -f "/home/user/.local/lib/assembly-dispatch-9099/amd64gnu+linux-9099-service.initd" ]; then
        sudo cp /home/user/.local/lib/assembly-dispatch-9099/amd64gnu+linux-9099-service.initd /etc/init.d/amd64gnu+linux-9099-service
        sudo chmod +x /etc/init.d/amd64gnu+linux-9099-service
        sudo rc-update add amd64gnu+linux-9099-service default
    fi

    echo "=== 6. Iniciando servicios (OpenRC) ==="
    sudo rc-service registro-diario-broadway restart || true
    sudo rc-service my-shell-9097-service restart || true
    sudo rc-service amd64gnu+linux-9099-service restart || true
fi

# NOTA PARA SISTEMAS SYSTEMD:
# Si la máquina de destino utiliza systemd en lugar de OpenRC, crea los siguientes servicios:
# 
# /etc/systemd/system/registro-diario-broadway.service
# ---------------------------------------------------
# [Unit]
# Description=Registro Diario Broadway Daemon
# After=network.target
# 
# [Service]
# Type=simple
# User=user
# ExecStart=/usr/bin/python3 /home/user/monoliths-llm/registro-diario-broadway-daemon.py
# Restart=always
# 
# [Install]
# WantedBy=multi-user.target
# 
# Habilitar y arrancar:
# sudo systemctl daemon-reload
# sudo systemctl enable --now registro-diario-broadway

echo "=== ¡Configuración completada con éxito! ==="
```

---

## 📌 10. Servicios Incluidos en el Repositorio
Los servicios web locales residen en este repositorio bajo `services/` y se vinculan simbólicamente a `~/.local/lib/`:
1. **Directorio `services/my-shell-9097` $\rightarrow$ `~/.local/lib/my-shell-9097`:**
   - `my_shell_9097.py`
   - `my-shell-9097-service.initd`
2. **Directorio `services/assembly-dispatch-9099` $\rightarrow$ `~/.local/lib/assembly-dispatch-9099`:**
   - `assembly_dispatch_9099.py`
   - `amd64gnu+linux-9099-service.initd`