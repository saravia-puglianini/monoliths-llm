# 📦 Guía Maestra de Replicación de Servicios y Entorno
## `monoliths-llm` + `monoliths-hm` + `amd64gnu+linux`

Este documento centraliza toda la configuración, servicios creados, cliente gráfico Xpra HTML5, binarios de ensamblador y pasos necesarios para clonar y replicar el entorno completo en otra máquina.

---

## 📑 Tabla de Contenidos
1. [Requisitos Previos del Sistema](#1-requisitos-previos-del-sistema)
2. [Estructura de Directorios Clave](#2-estructura-de-directorios-clave)
3. [Servicios y Paneles Web Locales](#3-servicios-y-paneles-web-locales)
   - [A. `registro-diario-broadway` (Puerto 8085)](#a-registro-diario-broadway-puerto-8085)
   - [B. `my-shell-9097-service` (Puerto 9097)](#b-my-shell-9097-service-puerto-9097)
   - [C. `amd64gnu+linux-9099-service` (Puerto 9099)](#c-amd64gnulinux-9099-service-puerto-9099)
   - [D. Implementación y Despliegue de Xpra HTML5 (Acceso Gráfico Remoto)](#d-implementación-y-despliegue-de-xpra-html5-acceso-gráfico-remoto)
4. [Extensiones de Navegador](#4-extensiones-de-navegador)
5. [Binarios Optimizados en Ensamblador y C (`Makefile.asm` y `monoliths-hm/Makefile`)](#5-binarios-optimizados-en-ensamblador-y-c)
6. [Sistema de Audio Modular Bajo Demanda y Plan QA](#6-sistema-de-audio-modular-bajo-demanda-y-plan-qa)
7. [Entorno de Sesión X11 (`.xinitrc` / `xprofile`)](#7-entorno-de-sesión-x11-xinitrc--xprofile)
8. [Script Maestro de Instalación y Replicación](#8-script-maestro-de-instalación-y-replicación)

---

## 1. Requisitos Previos del Sistema

Instala los siguientes paquetes en la nueva máquina (Debian / Alpine / Gentoo / Arch):

* **Herramientas de Compilación y Ensamblador:** `gcc`, `make`, `binutils` (GAS).
* **Librerías X11 y Gráficas:** `libx11-dev` / `libX11-devel`, `libxi-dev` / `libXi-devel`, `libxosd-dev` / `xosd`, `gtk+3.0`, `broadwayd` (GDK backend Broadway), `python3-gobject`.
* **Entorno y Ventanas:** `openbox`, `xbindkeys`, `feh`, `xcalib`, `picom`, `xinput`, `wmctrl`, `xdotool`, `st`, `scrot`, `yad`, `dash`.
* **Audio y Multimedia:** `alsa-utils`, `mpv`, `gstreamer-tools`, `gstreamer-plugins-base`, `gstreamer-plugins-good`, `piper` (o `festival`).
* **Acceso Remoto y Xpra:** `xpra` (servidor de display virtual / backend WebSocket).
* **Traducción y OCR:** `tesseract-ocr` (con paquetes `spa`, `deu`, `eng`), `apertium`.

---

## 2. Estructura de Directorios Clave

```
/home/user/
├── monoliths-llm/                  # Repo de automatizaciones, audio modular y daemon broadway
├── monoliths-hm/                   # Repo de entorno gráfico, xinitrc, my.shell.sh, Xpra y binarios OSD
├── amd64gnu+linux/                 # Repo de frontend, scripts de despliegue y panel 9099
├── .local/
│   ├── lib/
│   │   ├── my-shell-9097/          # Backend de my-shell-9097 (my_shell_9097.py)
│   │   └── assembly-dispatch-9099/ # Backend de assembly-dispatch-9099
│   └── state/                      # Bases de datos, jobs y logs de servicios
├── piper/                          # Modelos ONNX de voz neuronal
└── type-to-move-cursor/            # Subsistema de control de cursor por teclado
```

---

## 3. Servicios y Paneles Web Locales

### A. `registro-diario-broadway` (Puerto 8085)
- **Propósito:** Interfaz gráfica GTK3 sobre navegador (vía GDK Broadway) para control y justificación de actividades diarias, exportación a Jira y reportes PDF.
- **Archivos:**
  - `/home/user/monoliths-llm/registro-diario-broadwayd.py`
  - `/home/user/monoliths-llm/registro-diario-broadway-daemon.py`
  - `/home/user/monoliths-llm/registro-diario-broadway.openrc`
- **Instalación:**
  ```bash
  sudo cp /home/user/monoliths-llm/registro-diario-broadway.openrc /etc/init.d/registro-diario-broadway
  sudo chmod +x /etc/init.d/registro-diario-broadway
  sudo rc-update add registro-diario-broadway default
  sudo rc-service registro-diario-broadway start
  ```
- **Acceso:** `http://127.0.0.1:8085`

---

### B. `my-shell-9097-service` (Puerto 9097)
- **Propósito:** Panel web concurrente para interactuar con las opciones de `my.shell.sh` de `monoliths-hm` con salida en vivo de logs y control de procesos.
- **Archivos:**
  - `/home/user/.local/lib/my-shell-9097/my_shell_9097.py`
  - `/home/user/.local/lib/my-shell-9097/my-shell-9097-service.initd`
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
  - `/home/user/.local/lib/assembly-dispatch-9099/amd64gnu+linux-9099-service.initd`
- **Instalación:**
  ```bash
  sudo cp /home/user/.local/lib/assembly-dispatch-9099/amd64gnu+linux-9099-service.initd /etc/init.d/amd64gnu+linux-9099-service
  sudo chmod +x /etc/init.d/amd64gnu+linux-9099-service
  sudo rc-update add amd64gnu+linux-9099-service default
  sudo rc-service amd64gnu+linux-9099-service start
  ```
- **Acceso:** `http://127.0.0.1:9099`

---

### D. Implementación y Despliegue de Xpra HTML5 (Acceso Gráfico Remoto)
- **Ubicación:** `/home/user/monoliths-hm/xpra-html5/`
- **Detalles Técnicos:**
  - **Motor Web Puro:** Implementación del cliente web HTML5 independiente con decodificador de video Broadway (`broadway/Decoder.js`), descompresión Brotli/LZ4/Zlib, motor de audio Aurora (AAC/MP3/FLAC), workers en segundo plano y manejo de keycodes globales (`js/Keycodes.js`).
  - **Soporte de Ventanas Flotantes:** Módulo `js/Menu-custom.js` para arrastrar, minimizar y gestionar múltiples ventanas independientes de X11 en la pestaña del navegador.
  - **Compresión Estática:** Archivos pre-comprimidos `.br` y `.gz` para transmisión ultra rápida.
- **Formas de Ejecución:**
  1. **Servidor integrado con demonio Xpra (WebSocket nativo):**
     ```bash
     xpra start :100 --bind-ws=0.0.0.0:10000 --html=/home/user/monoliths-hm/xpra-html5/ --daemon=yes --start-child=openbox
     ```
  2. **Servidor HTTP local para desarrollo / pruebas:**
     ```bash
     cd /home/user/monoliths-hm/xpra-html5 && python3 -m http.server 8081
     ```
  - Acceso desde cualquier navegador en la red: `http://<IP_MAQUINA>:10000/index.html` o `http://localhost:8081`.

---

## 4. Extensiones de Navegador

### Extensión `horas-persistent-extension`
- **Ubicación:** `~/monoliths-llm/horas-persistent-extension`
- **Función:** Mantiene abierta la pestaña de `http://localhost:8085` de lunes a viernes en segundo plano y sincroniza con Jira.
- **Instalación:**
  1. En Google Chrome / Chromium ir a `chrome://extensions/`
  2. Activar **Developer mode**.
  3. Clic en **Load unpacked** y seleccionar `/home/user/monoliths-llm/horas-persistent-extension`.

---

## 5. Binarios Optimizados en Ensamblador y C

### A. Binarios en `monoliths-llm`:
- `alt_tab_maximize_emacs_asm`: Alt-Tab ultra rápido optimizado para Emacs en X11.
- `hotkey_listener_asm`: Listener global de teclas.
- `ram_report_asm`, `bat_asm`, `timer_asm`: Monitores en ASM puro.

```bash
cd /home/user/monoliths-llm
make -f Makefile.asm
gcc -no-pie -s hotkey_listener_asm.s -lX11 -o hotkey_listener_asm
gcc -no-pie -s ram_report_asm.s -o ram_report_asm
gcc -no-pie -s bat_asm.s -o bat_asm
gcc -no-pie -s timer_asm.s -o timer_asm
```

### B. Binarios en `monoliths-hm`:
- `bin/clock_osd` y `bin/hour_counter_osd` (usando `libxosd`).
- `bin/trackball_calibrator` (usando `libXi`).
- `bin/jbl_mic_loop`, `bin/jbl_mic_set`, `bin/check_usb_mouse_bt_optimizer` (ASM estático `-nostdlib`).
- `bin/personal_osdx`, `bin/volume_ctrl`, `bin/change_brightness`, `bin/play_pause_mpris`.

```bash
cd /home/user/monoliths-hm
make clean
make all
```

---

## 6. Sistema de Audio Modular Bajo Demanda y Plan QA

- Scripts `OUT=*.sh` en `monoliths-llm` para gestionar carga bajo demanda de módulos del kernel (`snd_sof_*`, `snd-usb-audio`, `snd-aloop`) con auto-apagado dinámico y loopback de latencia ultra baja (~0.5ms).
- **Suite QA Automatizada:**
  ```bash
  /home/user/monoliths-llm/qa_audio_test_plan.sh
  ```

---

## 7. Entorno de Sesión X11 (`.xinitrc` / `xprofile`)

Para configurar la sesión gráfica X11 completa en la máquina nueva:
```bash
ln -sf /home/user/monoliths-hm/xinitrc /home/user/.xinitrc
ln -sf /home/user/monoliths-hm/xprofile /home/user/.xprofile
```

---

## 8. Script Maestro de Instalación y Replicación

Guarda y ejecuta este script en la máquina nueva para dejar todo configurado y funcionando de inmediato:

```bash
#!/bin/bash
set -e

echo "=== 1. Creando directorios requeridos ==="
mkdir -p /home/user/.local/lib/assembly-dispatch-9099
mkdir -p /home/user/.local/lib/my-shell-9097
mkdir -p /home/user/.local/state/assembly-dispatch-9099
mkdir -p /home/user/.local/state/my-shell-9097
mkdir -p /home/user/.justificar

echo "=== 2. Enlaces simbólicos de sesión X11 ==="
ln -sf /home/user/monoliths-hm/xinitrc /home/user/.xinitrc
ln -sf /home/user/monoliths-hm/xprofile /home/user/.xprofile

echo "=== 3. Compilando binarios de monoliths-hm ==="
cd /home/user/monoliths-hm
make clean && make all

echo "=== 4. Compilando binarios de monoliths-llm ==="
cd /home/user/monoliths-llm
make -f Makefile.asm || true
gcc -no-pie -s hotkey_listener_asm.s -lX11 -o hotkey_listener_asm || true
gcc -no-pie -s ram_report_asm.s -o ram_report_asm || true
gcc -no-pie -s bat_asm.s -o bat_asm || true
gcc -no-pie -s timer_asm.s -o timer_asm || true

echo "=== 5. Instalando y arrancando servicios OpenRC ==="
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

    # Iniciar los servicios
    sudo rc-service registro-diario-broadway restart || true
    sudo rc-service my-shell-9097-service restart || true
    sudo rc-service amd64gnu+linux-9099-service restart || true
fi

echo "=== ¡Replicación completada con éxito! ==="
```
