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
	      (setq header-line-format nil)
	      (setq word-wrap t)
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
           "#hyperbola"       ;; "Comunidad de Hyperbola GNU/Linux-libre
           ;; "#trisquel"        ;; "Soporte y noticias de Trisquel GNU/Linux
           ;;"#linux"           ;; "Debate general sobre Linux y su ecosistema
           ;; "#fsfla"           ;; "Free Software Foundation Latin America
           ;; "#fsfeu"            ;; "Free Software Foundation Europe; noticias y debates
           ;;"#emacs"           ;; "Emacs: tips, configuraciones, extensiones
           "#hurd"            ;; "GNU Hurd: kernel libre, desarrollo y discusión
           ;;"#gcc"             ;; "GNU Compiler Collection: desarrollo y compilación
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
            :nick "telisp"
            :password ""
            :full-name "Trivial erc elisp script")))))
(my-auto-connect-erc)
;; ============================================================
;; Develop (agregar explicación del comando)
;;
;; Ejemplos de formato de línea:
;; [-_erc_08:13:53.244197__---]* SaraviaErcDevelo is testing log
;; [-_erc_08:14:56.576890__---]<Gry> hmm another testing log
;;
;; Adaptar el script para que siempre extraiga el texto desde una única
;; línea, tal como aparece en los ejemplos anteriores.
;; ============================================================
;; ============================================================
;; Develop — versión mejorada
;; ---
;; Descripción del flujo completo del módulo “Develop”.
;;
;; Este módulo añade un sistema automático que, cada vez que llega un
;; mensaje a un buffer ERC, realiza:
;;  1. Extracción del mensaje desde UNA sola línea.
;;  2. Traducción al alemán mediante un script externo.
;;  3. Lectura por voz utilizando espeak en un orden específico.
;;  4. Generación de una imagen del mensaje (ImageMagick).
;;  5. Visualización de la imagen con feh.
;;
;; Todo el proceso se ejecuta sin intervención del usuario y de forma
;; secuencial para evitar solapamientos de audio o ventanas.
;;
;; ------------------------------------------------------------
;; 1. Cuando ERC inserta una línea nueva, el hook `erc-insert-post-hook`
;;    ejecuta: `my/erc-espeak-nick+message-enqueue`, la entrada principal.
;;
;; 2. La línea recién insertada se toma tal cual, sin saltos, y se
;;    parsea mediante `my/erc-espeak-parse-line`, extrayendo:
;;      - timestamp
;;      - nick
;;      - mensaje
;;
;; 3. El mensaje se normaliza a una sola línea y se envía al traductor
;;    externo `googletrans-de`.
;;
;; 4. Se crea un elemento (timestamp nick msg-de msg-original) y se
;;    agrega a la cola `my/erc-espeak-msg-queue`.
;;
;; 5. Si no hay un timer activo, se inicia mediante
;;    `my/erc-espeak-start-timer`, que ejecuta el procesamiento cada 15s.
;;
;; 6. El procesador secuencial:
;;      a) Reproduce por voz el timestamp, el nick, la palabra “schrieb”
;;         y el mensaje traducido.
;;      b) Genera una imagen PNG con el mensaje.
;;      c) Detiene cualquier ventana previa de feh y muestra la imagen.
;;
;; 7. El ciclo continúa mientras existan mensajes en la cola. Si esta
;;    queda vacía, el sistema espera hasta que llegue uno nuevo.
;;
;; Resultado final:
;;   Cada línea recibida en ERC genera un flujo completo de voz e imagen
;;   sin intervención del usuario.
;; ============================================================
(defvar my/erc-espeak-msg-queue nil
  "Cola de mensajes pendientes para espeak y el buffer temporal.")
(defvar my/erc-espeak-timer nil
  "Timer encargado de procesar la cola de manera secuencial.")
;; -------------------------------------------------------------------
;; Extracción de timestamp, nick y mensaje desde una sola línea
;; -------------------------------------------------------------------
(defun my/erc-espeak-parse-line (line)
  "Analiza una línea al estilo ERC y devuelve (NICK MSG)."
  (when (string-match
         "^\\s-*\\(?:<\\([^>]+\\)>\\|\\* \\([^ ]+\\)\\)\\s-*\\(.*\\)$"
         line)
    (let ((nick (or (match-string 1 line) (match-string 2 line)))
          (msg (match-string 3 line)))
      (list nick (string-trim msg)))))
;; -------------------------------------------------------------------
;; Escape para evitar errores en `format`
;; -------------------------------------------------------------------
(defun my/escape-format (s)
  (replace-regexp-in-string "%" "%%" s))
(defface erc-msg-display-face
  '((t :height 250 :foreground "white" :background "black"))
  "Apariencia del mensaje estilo panel."
  :group 'erc)
;; -------------------------------------------------------------------
;; Muestra dos paneles
;; -------------------------------------------------------------------
(defun setup-panel (buf text bg buf1 buf2)
  (with-current-buffer buf
    (setq-local buffer-read-only nil)
    (erase-buffer)
    (setq-local truncate-lines nil
                window-truncate-lines nil
                mode-line-format nil
                header-line-format nil
                cursor-type nil
                line-spacing 0.3
                left-margin-width 5
                right-margin-width 5)
    (use-local-map
     (let ((map (make-sparse-keymap)))
       (define-key map (kbd "q")
         `(lambda () (interactive)
            (kill-buffer ,buf1)
            (kill-buffer ,buf2)))
       map))
    (setq-local my-buffer-background-remap
                (face-remap-add-relative 'default :background bg))
    (insert (propertize text 'face 'erc-msg-display-face))
    (goto-char (point-min))
    (setq-local buffer-read-only t)))
(defun my/erc-show-two-panel (text1 text2)
  "Show TEXT1 and TEXT2 in two vertically stacked buffers."
  (interactive)
  (let ((buf1 (get-buffer-create "*erc-panel-1*"))
        (buf2 (get-buffer-create "*erc-panel-2*")))
    
    ;; Puffer einrichten
    (cl-labels
        ((setup-panel (buf text bg)
           (with-current-buffer buf
             (setq-local buffer-read-only nil)
             (erase-buffer)
             (setq-local truncate-lines nil
                         word-wrap t
                         mode-line-format nil
                         header-line-format nil
                         cursor-type nil
                         line-spacing 0.3
                         left-margin-width 5
                         right-margin-width 5)
             (insert (propertize text
                                 'face (list :foreground "white"
                                             :background bg
                                             :height 250)))
             (goto-char (point-min))
             (setq-local buffer-read-only t))))
      
      (setup-panel buf1 text1 "black")
      (setup-panel buf2 text2 "gray10"))
    
    ;; Gemeinsame Tastaturbelegung mit übergebenen Puffern
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd "q")
        `(lambda ()
           (interactive)
           (when (buffer-live-p ,buf1) (kill-buffer ,buf1))
           (when (buffer-live-p ,buf2) (kill-buffer ,buf2))
           (delete-other-windows)))
      
      ;; Beide Puffer bekommen die gleiche Tastaturbelegung
      (with-current-buffer buf1
        (use-local-map (copy-keymap map)))
      
      (with-current-buffer buf2
        (use-local-map (copy-keymap map))))
    
    (delete-other-windows)
    (let ((win1 (selected-window))
          win2)
      (setq win2 (split-window-vertically))
      (set-window-buffer win1 buf1)
      (set-window-buffer win2 buf2)
      (select-window win1))))
;; -------------------------------------------------------------------
;; Procesamiento secuencial
;; -------------------------------------------------------------------
(defun my/erc-espeak-process-next ()
  "Procesa el siguiente mensaje de la cola usando espeak
y muestra un panel textual en un buffer."
  (when my/erc-espeak-msg-queue
    (let* ((item (pop my/erc-espeak-msg-queue)))
      (let ((nick     (my/escape-format (nth 0 item)))
            (msg-de   (my/escape-format (nth 1 item)))
            (orig-msg (my/escape-format (nth 2 item))))

        ;; lectura secuencial
        (start-process
         "espeak-seq" nil "bash" "-c"
         (mapconcat #'identity
                    (list
                     (format "espeak -s 135 -p 20 -a 160 -g 3 \"%s!\"" nick)
                     "espeak -vde -s 135 -p 20 -a 160 -g 3 \"schrieb!\""
                     (format "espeak -vde -s 135 -p 20 -a 160 -g 3 \"%s!\"" msg-de))
                    " && "))
        ;; panel en buffer — aquí ya NO puede fallar nunca
        (my/erc-show-two-panel
	 (format "%s schrieb %s" nick msg-de)
	 orig-msg)))))

;; -------------------------------------------------------------------
;; Timer secuencial
;; -------------------------------------------------------------------
(defun my/espeak-running-p ()
  "Devuelve t si espeak está en ejecución."
  (let ((output (shell-command-to-string "pgrep espeak")))
    (not (string-empty-p output))))
(defun my/erc-espeak-process-next-if-free ()
  "Procesa la cola solo si espeak no está en ejecución."
  (unless (my/espeak-running-p)
    (my/erc-espeak-process-next)))
(defun my/erc-espeak-start-timer ()
  "Activa un ciclo que procesa la cola cada 15s si espeak está libre."
  (run-at-time
   0 15
   (lambda ()
     (unless (my/espeak-running-p)
       (my/erc-espeak-process-next-if-free)))))
;; -------------------------------------------------------------------
;; Herramientas de depuración
;; -------------------------------------------------------------------
(defun my/erc-espeak-debug (label &rest args)
  "Imprime información de depuración con LABEL y ARGS."
  (if nil
      (let ((msg (mapconcat #'prin1-to-string args " ")))
        (message "[DEBUG] %s: %s" label msg))))
;; -------------------------------------------------------------------
;; Encolado con depuración
;; -------------------------------------------------------------------
(defun my/erc-espeak-nick+message-enqueue ()
  "Parsea la línea insertada en ERC y la encola para espeak y el panel."
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
			   ;; to build gt: https://saravia.org/monoliths-llm/plain/googletrans-de.py?h=develop
                           (concat "$HOME/googletrans/dist/googletrans-de "
                                   (shell-quote-argument orig-msg))))))
            (my/erc-espeak-debug "Encolando mensaje" nick msg-de orig-msg)
            (push (list nick msg-de orig-msg)
                  my/erc-espeak-msg-queue))))))
  ;; Asegurar que el timer esté activo
  (my/erc-espeak-start-timer))
(add-hook 'erc-insert-post-hook #'my/erc-espeak-nick+message-enqueue)
;;
;;                        ┌───────────────────────────┐
;;                        │   Llega una nueva línea   │
;;                        │        al buffer ERC      │
;;                        └─────────────┬─────────────┘
;;                                      │
;;                                      ▼
;;                     ┌───────────────────────────────────┐
;;                     │  erc-insert-post-hook se activa   │
;;                     │  llama a:                         │
;;                     │  my/erc-espeak-nick+message-enqueue
;;                     └──────────────────┬────────────────┘
;;                                        │
;;                                        ▼
;;                ┌────────────────────────────────────────────┐
;;                │   1. Obtener la línea recién insertada     │
;;                └─────────────────────┬──────────────────────┘
;;                                      │
;;                                      ▼
;;         ┌────────────────────────────────────────────────────────┐
;;         │ 2. Parsear timestamp/nick/mensaje desde UNA sola línea │
;;         │    usando my/erc-espeak-parse-line                     │
;;         └───────────────┬────────────────────────────────────────┘
;;                         │
;;               ¿Coincide con el formato ERC? ────────┐
;;                         │ NO                        │
;;                         ▼                           │
;;              ┌──────────────────┐                   │
;;              │  Descartar línea │                   │
;;              └───────────┬──────┘                   │
;;                          │                          │
;;                          └──────────────► FIN       │
;;                                                     │
;;                         │ YES                       │
;;                         ▼                           │
;;   ┌────────────────────────────────────────────────────────────────┐
;;   │ 3. Normalizar el mensaje a una única línea                     │
;;   │    y traducirlo al alemán mediante `googletrans-de`            │
;;   └─────────────────────────┬──────────────────────────────────────┘
;;                             │
;;                             ▼
;; ┌──────────────────────────────────────────────────────────────────────┐
;; │ 4. Encolar (nick msg-de msg-original) en my/erc-espeak-msg-queue     │
;; └──────────────────────────┬───────────────────────────────────────────┘
;;                            │
;;                            ▼
;;         ┌──────────────────────────────────────────┐
;;         │ 5. Si no hay timer activo, iniciarlo     │
;;         │    con my/erc-espeak-start-timer         │
;;         └──────────────────────┬───────────────────┘
;;                                │
;;                                ▼
;;      ┌──────────────────────────────────────────────┐
;;      │   Cada 15 segundos el timer ejecuta          │
;;      │        my/erc-espeak-process-next            │
;;      └─────────────────────────┬────────────────────┘
;;                                │
;;                                ▼
;; ┌───────────────────────────────────────────────────────────┐
;; │ 6a. Leer por voz con espeak en orden estricto:            │
;; │     1) timestamp                                          │
;; │     2) nick                                               │
;; │     3) "schrieb!"                                         │
;; │     4) mensaje en alemán                                  │
;; └─────────────────────────┬─────────────────────────────────┘
;;                           │
;;                           ▼
;;   ┌────────────────────────────────────────────────────────┐
;;   │ 6b. Generar imagen PNG con ImageMagick (convert):      │
;;   │     texto = ts + nick + schrieb + msg-de + " »» " + original
;;   └────────────────────────┬───────────────────────────────┘
;;                            │
;;                            ▼
;;     ┌───────────────────────────────────────────────────────────┐
;;     │ 6c. Cerrar feh previo (pkill feh) y mostrar nueva imagen  │
;;     │     en ventana flotante                                   │
;;     └──────────────────────────┬────────────────────────────────┘
;;                                │
;;                                ▼
;;        ┌──────────────────────────────────────────────┐
;;        │ 7. ¿Quedan más mensajes en la cola?          │
;;        └───────────┬──────────────────┬───────────────┘
;;                    │ SI               │ NO
;;                    ▼                  ▼
;;     ┌──────────────────────────────┐   ┌─────────────────────────┐
;;     │ Procesar siguiente en        │   │  Timer queda en espera  │
;;     │ próxima ejecución del timer  │   │  hasta nuevo mensaje    │
;;     └──────────────────────────────┘   └─────────────────────────┘
