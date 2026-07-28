# Sistema de Recordatorios Automatizados (Jira & Ops360)

Este repositorio contiene un sistema interactivo de alertas diseñado para asegurar el registro diario de horas de trabajo en **Jira** (Atlassian) y los marcajes de asistencia (toques) en **Ops360 Entelgy**. 

Las alertas se muestran visualmente a través de ventanas de diálogo interactivas en el escritorio y cuentan con sincronización automática mediante API.

---

## 📋 Componentes del Sistema

El sistema está compuesto por los siguientes scripts:

1. **`jira-reminder.sh`**: Script en Bash que monitorea las horas laborales pendientes de registro en el día actual (9:00 AM a 6:00 PM). Compara las horas contra un archivo local de registros y solicita justificar las horas faltantes mediante una interfaz gráfica. Además:
   - Permite transicionar de forma automática el estado de las tareas de Jira a *"En progreso"* e *"Hecho/Done"*.
   - Genera respaldos automáticos de los logs locales.
   - Sincroniza automáticamente los registros de Jira al inicio de cada iteración para soportar múltiples computadoras.
2. **`ops360-reminder.sh`**: Script en Bash enfocado en los 4 toques obligatorios de la jornada laboral en Entelgy:
   - **Entrada** (08:55 AM)
   - **Inicio Almuerzo** (12:55 PM)
   - **Fin Almuerzo** (14:00 PM)
   - **Salida** (17:55 PM)
3. **`run-reminders.sh`**: Un "driver" o despachador diseñado específicamente para entornos de **Crontab**. Debido a que cron solo permite programar tareas con una resolución mínima de 1 minuto, este script ejecuta un bucle de 1 minuto con intervalos de `sleep 5` para lanzar los recordatorios de Jira y Ops360 cada 5 segundos.
4. **`ver-horas.sh`**: Lanzado por el recordatorio de Jira para visualizar de forma amigable (mediante tablas interactivas) las últimas 50 entradas guardadas en el log local y generar reportes.
5. **`jira_helper.py`**: Script en Python que interactúa con la API de Atlassian Jira para listar tickets asignados, realizar transiciones de estado de tareas e historias padres, gestionar la subida de horas, y realizar la sincronización de logs entre múltiples dispositivos.

---

## 🛠️ Requisitos y Dependencias

Para instalar y ejecutar este sistema en otra máquina, debes contar con las siguientes herramientas instaladas en el sistema operativo:

* **`yad`**: Herramienta indispensable para la creación de diálogos gráficos desde la terminal.
  - En Debian/Ubuntu/Mint: `sudo apt install yad`
  - En Arch/Manjaro: `sudo pacman -S yad`
  - En Fedora/CentOS/RHEL/Rocky: `sudo dnf install yad`
* **`python3`**: Para la ejecución de `jira_helper.py` (utiliza únicamente librerías estándar como `urllib`, `json`, y `base64`, por lo que no requiere de dependencias externas por `pip`).
* **Utilidades del sistema**: `bash`, `pgrep` y `ps` (parte de `procps` para el manejo de archivos de bloqueo `.pid`).
* **Navegador Web**: Un navegador configurado en el sistema (`firefox`, `chrome`, `chromium` o el comando general `xdg-open`) para abrir los portales web cuando el usuario lo solicite.

---

## 📂 Archivos de Configuración y Datos

Los datos persistentes y configuraciones se almacenan a nivel de usuario en las siguientes ubicaciones:

* **`~/.justificar/jira_config`**: Archivo de credenciales de Jira. Si no existe, el script de recordatorio solicitará crearlo interactivamente la primera vez. Estructura interna:
   ```ini
   JIRA_EMAIL="tu-correo@dominio.com"
   JIRA_API_TOKEN="token_generado_en_atlassian"
   JIRA_DOMAIN="https://tu-organizacion.atlassian.net"
   ```
* **`~/.justificar/justificar.csv`**: Base de datos local plana donde se registran las horas guardadas.
  - Formato: `YYYY-MM-DD;Hora (ej: 9am o 2pm);Proyecto/Ticket;Descripción;[Link-opcional]`
* **`~/.justificar/backups/`**: Directorio donde se guardan copias de seguridad de `justificar.csv` cada vez que se arranca el script (se auto-limpia manteniendo únicamente los últimos 10 respaldos).
* **`~/.pause_until`**: Contiene un timestamp para pausar temporalmente las notificaciones (si el usuario así lo decide).
* **`~/.holidays`**: Archivo de texto plano con fechas de feriados (en formato `MM-DD`, una por línea) para que los recordatorios no se ejecuten en esos días.
* **`/tmp/ops360_t[1-4]_YYYY-MM-DD`**: Archivos temporales tipo flag creados por `ops360-reminder.sh` para recordar qué toques diarios ya han sido marcados exitosamente y no volver a alertar por ellos durante el día.

---

## 🔄 Funcionamiento de Sincronización Multi-dispositivo

Para permitir que el sistema funcione en dos o más computadoras a la vez:
1. Cada vez que `jira-reminder.sh` realiza un ciclo de verificación, ejecuta el comando `python3 jira_helper.py sync <FECHA>`.
2. Este comando se conecta a la API de Jira y busca todas las horas registradas por el usuario logueado para ese día específico.
3. Si encuentra registros en Jira que no están en el archivo local `justificar.csv`, los descarga y los inserta localmente asociándolos automáticamente a las horas de trabajo correspondientes de la mañana/tarde.
4. De esta manera, el script en el segundo dispositivo sabe exactamente qué horas ya registraste en el primero y te preguntará únicamente por el saldo restante sin duplicar información.

---

## 🚀 Guía de Instalación Paso a Paso (Para Sistemas IA y Desarrolladores)

Sigue estos pasos detallados para instalar el sistema en una máquina limpia:

### Paso 1: Clonar y Ubicar los Archivos
Coloca los archivos de este repositorio en el directorio deseado (se asume `/home/user/monoliths-llm/` para los ejemplos de configuración, ajusta si es necesario).

### Paso 2: Otorgar Permisos de Ejecución
Asegúrate de dar permisos de ejecución a todos los scripts del sistema:
```bash
chmod +x /home/user/monoliths-llm/*.sh
chmod +x /home/user/monoliths-llm/*.py
```

### Paso 3: Configuración de Credenciales de Jira
Puedes dejar que el script te pregunte interactivamente al iniciar por primera vez, o puedes crear la configuración manualmente:
```bash
mkdir -p ~/.justificar
cat <<EOF > ~/.justificar/jira_config
JIRA_EMAIL="tu_email_de_jira@dominio.com"
JIRA_API_TOKEN="tu_api_token_de_atlassian_jira"
JIRA_DOMAIN="https://tu-organizacion.atlassian.net"
EOF
chmod 600 ~/.justificar/jira_config
```

### Paso 4: Automatizar la Ejecución

Existen dos formas principales de automatizar y mantener vivos estos scripts en segundo plano:

#### Opción A: Mediante Crontab (Portabilidad simple)

Dado que los scripts requieren comunicarse con el servidor de pantallas gráfico (X11 o Wayland) para desplegar las ventanas de `yad`, es obligatorio proveer las variables de entorno `DISPLAY` y `XAUTHORITY` dentro del cron.

1. Abre la edición de tu crontab de usuario:
   ```bash
   crontab -e
   ```
2. Añade la siguiente línea para ejecutar el orquestador cada minuto de lunes a viernes:
   ```cron
   * * * * 1-5 env DISPLAY=:0 XAUTHORITY=/home/user/.Xauthority /home/user/monoliths-llm/run-reminders.sh >/dev/null 2>&1
   ```
   > ⚠️ **IMPORTANTE:**
   > - Reemplaza `/home/user/` por la ruta absoluta de tu directorio Home.
   > - Asegúrate de que `DISPLAY` (comúnmente `:0`) y `XAUTHORITY` apunten a los valores correctos de tu sesión activa. Puedes validar tus valores actuales ejecutando `echo $DISPLAY` y `echo $XAUTHORITY` en tu terminal gráfica.

---

#### Opción B: Mediante Systemd User Units (Recomendado para persistencia y reinicios automáticos)

Si la máquina destino utiliza `systemd`, se puede configurar como servicios de usuario (`--user`). Esta opción mantiene los scripts corriendo constantemente como "daemons" en segundo plano, controlando de manera nativa los reinicios ante fallas.

1. Crea el directorio de servicios de usuario si no existe:
   ```bash
   mkdir -p ~/.config/systemd/user/
   ```
2. Crea el archivo de servicio para Jira en `~/.config/systemd/user/jira-reminder.service`:
   ```ini
   [Unit]
   Description=Jira Reminder (Persistent Daemon)

   [Service]
   Type=simple
   ExecStart=/home/user/monoliths-llm/jira-reminder.sh
   Restart=always
   RestartSec=10
   Environment=DISPLAY=:0
   Environment=XAUTHORITY=/home/user/.Xauthority

   [Install]
   WantedBy=default.target
   ```
3. Crea el archivo de servicio para Ops360 en `~/.config/systemd/user/ops360-reminder.service`:
   ```ini
   [Unit]
   Description=Ops360 Reminder (Persistent Daemon)

   [Service]
   Type=simple
   ExecStart=/home/user/monoliths-llm/ops360-reminder.sh
   Restart=always
   RestartSec=10
   Environment=DISPLAY=:0
   Environment=XAUTHORITY=/home/user/.Xauthority

   [Install]
   WantedBy=default.target
   ```
4. Recarga el demonio de systemd de usuario, habilita e inicia los servicios:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now jira-reminder.service ops360-reminder.service
   ```
5. Para verificar que estén corriendo correctamente:
   ```bash
   systemctl --user status jira-reminder.service ops360-reminder.service
   ```