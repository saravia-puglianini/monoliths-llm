;; ============================================================
;; ERC: Sin saltos de línea, sin fill, timestamps con microsegundos
;; ============================================================
(with-eval-after-load 'erc
  ;; -----------------------------------------------
  ;; Desactivar módulo que corta texto
  ;; -----------------------------------------------
  (setq erc-modules (remove 'fill erc-modules))
  (add-hook 'erc-mode-hook
            (lambda ()
              (when (bound-and-true-p erc-fill-mode)
                (erc-fill-mode -1))
              (turn-off-auto-fill)
              (visual-line-mode -1)
              (setq truncate-lines t)
              (setq-default auto-fill-function nil)
              ;; Línea larga sin wrapping
              (setq erc-fill-column 1000)))
  ;; -----------------------------------------------
  ;; Timestamps con microsegundos sin romper línea
  ;; -----------------------------------------------
  (setq erc-timestamp-format "[-_erc_%H:%M:%S.%6N__---]")
  (defun my-erc-insert-timestamp (&optional type)
    "Insert timestamp at end of line without wrapping."
    (let ((ts (format-time-string erc-timestamp-format))
          (proc (get-buffer-process (current-buffer))))
      ;; Insertar timestamp al final del buffer
      (save-excursion
	(goto-char (point-max))
	(insert " " ts))
      ;; Actualizar marcador solo si hay proceso activo
      (when proc
	(set-marker (process-mark proc) (point)))))
  ;; Configurar ERC para usar nuestra función
  (setq erc-insert-timestamp-function #'my-erc-insert-timestamp)
  (defun my-erc-setup-timestamps ()
    "Activar timestamps en ERC."
    (erc-timestamp-mode t))
  (add-hook 'erc-mode-hook #'my-erc-setup-timestamps))
(setq erc-hide-list '("JOIN" "PART" "QUIT" "NICK" "MODE"))
(defun my-auto-connect-erc ()
  (setq erc-autojoin-channels-alist
	'(("Libera.Chat"
           ;; --- Tus canales originales ---
           ;; "#gnu-linux-libre" ;; "Canal principal sobre GNU/Linux-libre, noticias y soporte
           ;; "#javascript"      ;; "Discusión sobre JavaScript y ecosistema web
           ;; "#hyperbola"       ;; "Comunidad de Hyperbola GNU/Linux-libre
           ;; "#trisquel"        ;; "Soporte y noticias de Trisquel GNU/Linux
           "#linux"           ;; "Debate general sobre Linux y su ecosistema
           ;; "#fsfla"           ;; "Free Software Foundation Latin America
           ;; "#fsfeu"            ;; "Free Software Foundation Europe; noticias y debates
           "#emacs"           ;; "Emacs: tips, configuraciones, extensiones
           ;; "#hurd"            ;; "GNU Hurd: kernel libre, desarrollo y discusión
           ;; "#gcc"             ;; "GNU Compiler Collection: desarrollo y compilación
           ;; "#fsf"             ;; "Free Software Foundation; filosofía y noticias

           ;; ;; --- Software libre / Filosofía ---
           ;; "#libreplanet"      ;; "Comunidad asociada a FSF/LibrePlanet; debates éticos y técnicos
           ;; "#publiccode"       ;; "Estándares y software público; políticas tecnológicas libres
           ;; "#copyleft"         ;; "Licencias libres, GPL, discusiones legales/filosóficas

           ;; ;; --- Distros y ecosistema libre ---
           ;; "#parabola"         ;; "Soporte y desarrollo Parabola GNU/Linux-libre
           ;; "#guix"             ;; "Usuarios de Guix: reproducibilidad, paquetes, entorno puro
           ;; "#guix-devel"       ;; "Canal técnico del desarrollo de Guix y Guix System
           ;; "#debian-free"      ;; "Enfoque en la parte 100% libre y DFSG de Debian
           ;; "#alpine-linux"     ;; "Sistema minimalista; discusiones técnicas UNIX/pure-SO

           ;; ;; --- Programación general ---
           ;; "#scheme"           ;; "Discusión sobre Scheme; ideal para quienes vienen de Elisp
           ;; "#guile"            ;; "GNU Guile: extensiones de GNU, scripting, macros, VM
           ;; "#rust"             ;; "Lenguaje Rust: sistemas seguros, compilación, crates
           ;; "#go-nuts"          ;; "Go/Golang: concurrencia, microservicios, herramientas
           ;; "#python"           ;; "Python: librerías, preguntas técnicas, packaging
           ;; "#bash"             ;; "Shell scripting POSIX, funciones, pipes, truquitos UNIX
           ;; "#sh"               ;; "Enfoque estricto POSIX sh; muy minimalista y técnico

           ;; ;; --- Desarrollo GNU core) ---
           ;; "#binutils"         ;; "Desarrollo de binutils: ensamblador, linker, herramientas
           ;; "#coreutils"        ;; "Utilidades base de GNU: ls, cp, mv, etc
           ;; "#make"             ;; "GNU Make: recetas, automatización, reglas avanzadas
           ;; "#gdb"              ;; "Depurador GNU: debugging, extensiones, scripts en Python
           ;; "#glibc"            ;; "Biblioteca estándar de GNU C; muy técnico
           ;; "#gettext"          ;; "Localización e internacionalización en GNU
           ;; "#texinfo"          ;; "Sistema de documentación oficial del proyecto GNU

           ;; ;; --- Emacs & Lisp ---
           ;; "#org-mode"         ;; "Org Mode: productividad, literate programming, GTD
           ;; "#magit"            ;; "Interfaz Git para Emacs; flujo de trabajo con repos
           ;; "#emacs-beginners"  ;; "Soporte accesible para nuevas personas
           ;; "#commonlisp"       ;; "Discusión general de Common Lisp, ecosistema y librerías
           ;; "#clojure"          ;; "Lenguaje Lisp sobre la JVM; funcional y práctico

           ;; ;; --- Hacking, cultura y privacidad ---
           ;; "#cybersecurity"    ;; "Seguridad informática desde un ángulo técnico y ético
           ;; "#cryptography"     ;; "Criptografía moderna, protocolos, análisis
           ;; "#sdf"              ;; "Comunidad clásica hacker/UNIX vinculada al SDF Public Access
           ;; "#tildeverse"       ;; "Nodos tilde; cultura hacker suave y social
           ;; "#tilde.club"       ;; "Otro nodo tilde: publicaciones, terminal, web minimalista

           ;; ;; --- Infraestructura, protocolos, redes ---
           ;; "#ircv3"            ;; "Desarrollo del estándar IRCv3; muy orientado a protocolo
           ;; "#dns"              ;; "Sistema DNS: servidores autoritativos, BIND, técnicas
           ;; "#netops"           ;; "Operación de redes, routing, BGP, infra crítica
           )))
  (run-at-time
   1
   nil
   (lambda ()
     (progn
       (message "Ingresando a irc")
       (erc :server "irc.libera.chat"
            :port "6667"
            :nick "erc_develop"
            :password ""
            :full-name "Enmanuel Saravia")))))
(my-auto-connect-erc)
;; ============================================================
;; Develop (agregue explicación del comando)
;; [-_erc_08:13:53.244197__---]* SaraviaErcDevelo is testing log
;; [-_erc_08:14:56.576890__---]<Gry> hmm another testing log
;; adaptar el siguiente script para que siempre extraiga el texto de
;; una sola línea como se ve en el mensaje de SaraviaErcDevelo y <Gry>
;; ============================================================
;; ============================================================
;; Develop — versión mejorada
;; ---
;; # ✅ **Descripción completa del flujo del script *Develop — versión
;; mejorada*** El módulo *Develop* añade un sistema automatizado que,
;; cada vez que llega un mensaje a un buffer ERC, extrae la
;; información principal, la traduce al alemán, lo lee en voz alta con
;; *espeak* en un orden específico y además genera una imagen visual
;; del mensaje usando *ImageMagick* y *feh*. Todo esto ocurre sin
;; intervención del usuario y de forma secuencial para evitar
;; solapamientos.A continuación se detalla el flujo completo:
;; ---
;; ## **1. Recepción de una nueva línea en ERC**
;; ERC inserta un mensaje en el buffer.
;; Inmediatamente se ejecuta el hook `erc-insert-post-hook`, que llama a:
;; ```
;; my/erc-espeak-nick+message-enqueue
;; ```
;; Este es el punto de entrada del sistema.
;; ---
;; ## **2. Extracción de la información desde una sola línea**
;; El mensaje recién insertado se toma **exactamente como una sola
;; línea** (sin saltos, sin wrapping).
;; La función:
;; ```
;; my/erc-espeak-parse-line
;; ```
;; analiza la línea y extrae:
;; * **timestamp** en microsegundos
;; * **nick** del remitente
;; * **mensaje original**
;; Solo las líneas en formato estándar ERC con timestamp serán procesadas.
;; ---
;; ## **3. Normalización y traducción del mensaje**
;; El mensaje se limpia para asegurar que queda en una única línea.
;; Luego se pasa a un script externo que lo traduce al alemán:
;; ```
;; googletrans-de
;; ```
;; El resultado se prepara para TTS (text-to-speech).
;; ---
;; ## **4. Encolado del procesamiento**
;; Se crea un item de trabajo con:
;; ```
;; (timestamp nick mensaje_en_alemán mensaje_original)
;; ```
;; y se agrega a:
;; ```
;; my/erc-espeak-msg-queue
;; ```
;; La cola mantiene los mensajes pendientes de lectura y visualización.
;; ---
;; ## **5. Activación del timer secuencial**
;; Si aún no existe un timer activo, se crea uno mediante:
;; ```
;; my/erc-espeak-start-timer
;; ```
;; Este timer ejecuta cada 15 segundos:
;; ```
;; my/erc-espeak-process-next
;; ```
;; La separación temporal evita que *espeak* y *feh* se superpongan o
;; compitan por recursos gráficos y de audio.
;; ---
;; ## **6. Procesamiento del siguiente mensaje en la cola**
;; `my/erc-espeak-process-next` toma el primer mensaje pendiente y realiza:
;; ### **a) Reproducción por voz con espeak**
;; Se leen secuencialmente:
;; 1. el **timestamp**,
;; 2. el **nick**,
;; 3. la palabra alemana *"schrieb!"*,
;; 4. el **mensaje traducido al alemán**.
;; Cada fragmento se ejecuta en cadena `&&` para garantizar que se
;; respeta el orden.
;; ---
;; ### **b) Generación de una imagen con el mensaje**
;; La función crea una imagen PNG temporal mediante `convert`:
;; * fondo negro
;; * texto blanco
;; * tipografía *Liberation Sans Bold Italic*
;; * centrado
;; * borde configurable
;; El texto en la imagen combina:
;; ```
;; timestamp + nick + "schrieb" + mensaje_en_alemán + »» + mensaje_original
;; ```
;; Esto sirve como overlay visual del mensaje entrante.
;; ---
;; ### **c) Presentación de la imagen en pantalla**
;; Primero se detiene cualquier instancia previa de `feh`:
;; ```
;; pkill feh
;; ```
;; Luego se lanza una nueva ventana borderless mostrando la imagen recién creada.
;; ---
;; ## **7. Repetición del ciclo**
;; Cada vez que la cola aún tiene mensajes, el timer continúa llamando
;; a `my/erc-espeak-process-next`.Cuando la cola queda vacía, el timer
;; queda inactivo hasta que un nuevo mensaje llegue al buffer ERC.
;; ---
;; ## **Resultado final**
;; Cada mensaje recibido en ERC produce automáticamente:
;; 1. **Extracción limpia** desde una sola línea.
;; 2. **Traducción automática al alemán.**
;; 3. **Lectura secuencial por voz (timestamp → nick → ‘schrieb’ → mensaje).**
;; 4. **Generación de una imagen representando el mensaje.**
;; 5. **Presentación visual en ventana flotante.**
;; Todo ocurre sin intervención manual y sin conflictos entre
;; procesos, manteniendo un flujo ordenado y estable.
;; ---
;;     ┌─────────────────────────┐
;;     │   Mensaje llega a ERC   │
;;     └─────────────┬───────────┘
;;                   │
;;                   ▼
;;   ┌────────────────────────────────┐
;;   │ erc-insert-post-hook dispara   │
;;   │ my/erc-espeak-nick+message-enqueue
;;   └────────────────┬────────────────┘
;;                    │
;;                    ▼
;;     ┌────────────────────────────────────┐
;;     │ 1. Tomar la línea recién insertada │
;;     └───────────────────┬────────────────┘
;;                         │
;;                         ▼
;;         ┌──────────────────────────────────┐
;;         │ 2. Parseo de timestamp / nick /  │
;;         │    mensaje con my/parse-line     │
;;         └───────────────────┬──────────────┘
;;                             │
;;                  ¿Coincide formato ERC? ─────┐
;;                             │ NO             │
;;                             ▼                │
;;                    (descartar línea)         │
;;                             │                │
;;                             └──────► Fin     │
;;                             │                │
;;                             ▼ YES            │
;;         ┌──────────────────────────────────┐ │
;;         │ 3. Normalizar mensaje a 1 línea  │ │
;;         │    y traducir al alemán          │ │
;;         └───────────────────┬──────────────┘ │
;;                             │                │
;;                             ▼                │
;;   ┌──────────────────────────────────────────────────┐
;;   │ 4. Encolar (timestamp nick msg-de msg-original)  │
;;   │    en my/erc-espeak-msg-queue                    │
;;   └─────────────────────────┬────────────────────────┘
;;                             │
;;                             ▼
;;        ┌────────────────────────────────────┐
;;        │ 5. Activar timer si no existe      │
;;        │    my/erc-espeak-start-timer       │
;;        └────────────────────┬───────────────┘
;;                             │
;;                             ▼
;;      (Cada 15 segundos el timer ejecuta)
;;      ┌───────────────────────────────────────┐
;;      │     my/erc-espeak-process-next        │
;;      └───────────────────────┬───────────────┘
;;                              │
;;                              ▼
;;             ┌───────────────────────────────────┐
;;             │ 6a. Reproducir con espeak:        │
;;             │     timestamp → nick → schrieb →  │
;;             │     msg-de                        │
;;             └──────────────────┬────────────────┘
;;                                │
;;                                ▼
;; ┌──────────────────────────────────────────────────┐
;; │ 6b. Crear imagen con ImageMagick (convert)       │
;; │     texto = ts nick schrieb msg-de »» original   │
;; │     generar PNG temporal                         │
;; └─────────────────────────────┬────────────────────┘
;;                               │
;;                               ▼
;;   ┌────────────────────────────────────────────────┐
;;   │ 6c. Cerrar feh previo y mostrar la nueva imagen│
;;   │     con feh --borderless                       │
;;   └────────────────────────────┬───────────────────┘
;;                                │
;;                                ▼
;;            ┌────────────────────────────────┐
;;            │ 7. ¿La cola tiene más mensajes?│
;;            └───────────┬────────────┬───────┘
;;                        │ SI         │ NO
;;                        ▼            ▼
;;    ┌──────────────────────────┐     ┌──────────────────┐
;;    │ Procesar el siguiente    │     │ Queda en espera  │
;;    │ mensaje en próxima       │     │ hasta nuevo msg  │
;;    │ ejecución del timer      │     └──────────────────┘
;;    └──────────────────────────┘
;; ============================================================
(defvar my/erc-espeak-msg-queue nil
  "Cola de mensajes pendientes para espeak y feh.")
(defvar my/erc-espeak-timer nil
  "Timer encargado de procesar la cola secuencialmente.")
;; -------------------------------------------------------------------
;; Extracción de timestamp, nick y mensaje desde UNA SOLA LÍNEA
;; -------------------------------------------------------------------
(defun my/erc-espeak-parse-line (line)
  "Parsea una línea estilo ERC en una lista (NICK MSG)."
  (when (string-match
         "^\\s-*\\(?:<\\([^>]+\\)>\\|\\* \\([^ ]+\\)\\)\\s-*\\(.*\\)$"
         line)
    (let ((nick (or (match-string 1 line) (match-string 2 line)))
          (msg (match-string 3 line)))
      (list nick (string-trim msg)))))
;; -------------------------------------------------------------------
;; Procesamiento secuencial
;; -------------------------------------------------------------------
(defun my/erc-espeak-process-next ()
  "Procesa el siguiente mensaje de la cola usando espeak y genera la imagen."
  (when my/erc-espeak-msg-queue
    (let* ((item (pop my/erc-espeak-msg-queue)))
      (let ((nick (nth 0 item))
            (msg-de (nth 1 item))
            (orig-msg (nth 2 item)))
        ;; lectura secuencial en voz
        (start-process
         "espeak-seq" nil "bash" "-c"
         (mapconcat #'identity
                    (list
                     (format "espeak -s 135 -p 20 -a 160 -g 3 \"%s!\"" nick)
                     "espeak -vde -s 135 -p 20 -a 160 -g 3 \"schrieb!\""
                     (format "espeak -vde -s 135 -p 20 -a 160 -g 3 \"%s!\"" msg-de))
                    " && "))
        ;; imagen con mensaje original + traducción
        (let* ((tempfile (make-temp-file "erc-msg-" nil ".png"))
               (resolution (string-trim
                            (shell-command-to-string
                             "xrandr 2>/dev/null | grep '*' | sed 's/.* \\([0-9]\\+x[0-9]\\+\\).*/\\1/'")))
               (resolution (if (string-empty-p resolution) "800x600" resolution))
               (width (string-to-number (car (split-string resolution "x"))))
               (margin 50)
               (size-opt (format "%dx" (- width (* 2 margin))))
               (text (format "%s %s schrieb %s »» %s"
                             nick msg-de orig-msg)))
          ;; generar imagen
          (call-process
           "convert" nil nil nil
           "-size" size-opt
           "-background" "black"
           "-fill" "white"
           "-pointsize" "36"
           "-font" "/usr/share/fonts/liberation/LiberationSans-BoldItalic.ttf"
           "-gravity" "center"
           (concat "caption:" text)
           "-bordercolor" "black"
           "-border" (number-to-string margin)
           tempfile)
          ;; reemplazar imagen en feh
          (ignore-errors (call-process "pkill" nil nil nil "feh"))
          (start-process "feh-msg" nil "feh" "--borderless" tempfile))))))
;; -------------------------------------------------------------------
;; Timer secuencial
;; -------------------------------------------------------------------
(defun my/espeak-running-p ()
  "Devuelve t si espeak está corriendo."
  (let ((output (shell-command-to-string "pgrep espeak")))
    (not (string-empty-p output))))

(defun my/erc-espeak-process-next-if-free ()
  "Procesa la cola solo si espeak no está corriendo."
  (unless (my/espeak-running-p)
    (my/erc-espeak-process-next)))

(defun my/erc-espeak-start-timer ()
  "Bucle infinito que procesa la cola cada 15s, esperando a que espeak termine."
  (run-at-time 0 15
               (lambda ()
                 (if (not (my/espeak-running-p))
                     (my/erc-espeak-process-next-if-free)))))

;; -------------------------------------------------------------------
;; Debug helpers
;; -------------------------------------------------------------------
(defun my/erc-espeak-debug (label &rest args)
  "Imprime debug info con LABEL y ARGS en *Messages*."
  (if nil
      (let ((msg (mapconcat #'prin1-to-string args " ")))
	(message "[DEBUG] %s: %s" label msg))))

;; -------------------------------------------------------------------
;; Procesamiento secuencial con debug
;; -------------------------------------------------------------------
(defun my/erc-espeak-process-next ()
  "Procesa el siguiente mensaje de la cola usando espeak y genera la imagen, con debug."
  (when my/erc-espeak-msg-queue
    (let ((item (pop my/erc-espeak-msg-queue)))
      (my/erc-espeak-debug "Procesando item" item)
      (condition-case err
          (let ((nick (nth 0 item))
                (msg-de (nth 1 item))
                (orig-msg (nth 2 item)))
            ;; lectura secuencial en voz
            (my/erc-espeak-debug "Llamando a espeak con" nick msg-de)
            (start-process
             "espeak-seq" nil "bash" "-c"
             (mapconcat #'identity
                        (list
                         (format "espeak -s 135 -p 20 -a 160 -g 3 \"%s!\"" nick)
                         "espeak -vde -s 135 -p 20 -a 160 -g 3 \"schrieb!\""
                         (format "espeak -vde -s 135 -p 20 -a 160 -g 3 \"%s!\"" msg-de))
                        " && "))
            ;; imagen con mensaje original + traducción
            (let* ((tempfile (make-temp-file "erc-msg-" nil ".png"))
                   (resolution (string-trim
                                (shell-command-to-string
                                 "xrandr 2>/dev/null | grep '*' | sed 's/.* \\([0-9]\\+x[0-9]\\+\\).*/\\1/'")))
                   (resolution (if (string-empty-p resolution) "800x600" resolution))
                   (width (string-to-number (car (split-string resolution "x"))))
                   (margin 50)
                   (size-opt (format "%dx" (- width (* 2 margin))))
                   (text (format "%s schrieb %s »» %s" nick msg-de orig-msg)))
              (my/erc-espeak-debug "Generando imagen en" tempfile)
              (call-process
               "convert" nil nil nil
               "-size" size-opt
               "-background" "black"
               "-fill" "white"
               "-pointsize" "36"
               "-font" "/usr/share/fonts/liberation/LiberationSans-BoldItalic.ttf"
               "-gravity" "center"
               (concat "caption:" text)
               "-bordercolor" "black"
               "-border" (number-to-string margin)
               tempfile)
              ;; reemplazar imagen en feh
              (ignore-errors (call-process "pkill" nil nil nil "feh"))
              (start-process "feh-msg" nil "feh" "--borderless" tempfile)))
        (error (my/erc-espeak-debug "Error procesando mensaje" err))))))

;; -------------------------------------------------------------------
;; Función de enqueue con debug
;; -------------------------------------------------------------------
(defun my/erc-espeak-nick+message-enqueue ()
  "Parsea la línea nueva insertada en ERC y la encola para espeak/feh con debug."
  (my/erc-espeak-debug "Execute")
  (when (eq major-mode 'erc-mode)
    (save-excursion
      (goto-char (line-beginning-position))
      (let* ((line (buffer-substring-no-properties
                    (line-beginning-position)
                    (line-end-position)))
             (parsed (my/erc-espeak-parse-line line)))
	(my/erc-espeak-debug "Line" line)
	(my/erc-espeak-debug "Parsed" parsed)
        (when parsed
          (let* ((nick (nth 0 parsed))
                 (orig-msg (nth 1 parsed))
                 (msg-de (string-trim
                          (shell-command-to-string
			   ;; for build the binary https://saravia.org/monoliths-llm/plain/googletrans-de.py?h=develop
                           (concat "$HOME/googletrans/dist/googletrans-de "
                                   (shell-quote-argument orig-msg))))))
            (my/erc-espeak-debug "Encolando mensaje" nick msg-de orig-msg)
            (push (list nick msg-de orig-msg)
                  my/erc-espeak-msg-queue))))))
  ;; asegurar timer activo
  (my/erc-espeak-start-timer))

(add-hook 'erc-insert-post-hook #'my/erc-espeak-nick+message-enqueue)
