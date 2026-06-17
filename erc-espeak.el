;; only ROOM MESSAGE

(setq erc-insert-pre-hook nil)

;; only track NICK & MESSAGES

(setq erc-hide-list '("JOIN" "PART" "QUIT" "NICK" "MODE"))

;; espeak NICK

(defun my/erc-espeak-nick-reinsert-simple ()
  "Versión simple que solo anuncia nicks sin verificar propiedad."
  (interactive)
  (when (eq major-mode 'erc-mode)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^[<{]\\([^>}]*\\)[>}]" (point-max) t)
        (let ((nick-match (match-string 1)))
          (start-process "espeak-nick" nil "espeak" 
			 "-s" "135" "-p" "20" "-a" "160" "-g" "3"
                         (format "%s has written" nick-match)))))))

(add-hook 'erc-insert-post-hook 'my/erc-espeak-nick-reinsert-simple)

;; espeak NICK + MESSAGE only

(defun my/erc-espeak-nick+message-reinsert-simple ()
  "Anuncia el nick y luego el mensaje completo tal como aparece en el buffer."
  (interactive)
  (when (eq major-mode 'erc-mode)
    (save-excursion
      ;; Ir al inicio del mensaje recién insertado
      (goto-char (point-min))
      ;; Captura: 1) Nick  2) Mensaje
      (when (re-search-forward "^[<{]\\([^>}]+\\)[>}]\\s-*\\(.*\\)$" (point-max) t)
        (let ((nick (match-string 1))
              (msg  (match-string 2)))
          ;; Anuncia nick
          (start-process "espeak-nick" nil "espeak"
			 "-s" "135" "-p" "20" "-a" "160" "-g" "3"
                         (format "%s scrieb! %s" nick msg)))))))

(add-hook 'erc-insert-post-hook 'my/erc-espeak-nick+message-reinsert-simple)

;; NICE WAY

(defvar my/erc-espeak-msg-queue nil
  "Cola de mensajes pendientes para espeak y feh.")

(defvar my/erc-espeak-timer nil
  "Timer que procesa los mensajes de la cola periódicamente.")

(defun my/erc-espeak-clean-msg (msg)
  "Eliminar la marca de tiempo ERC del mensaje."
  (string-trim
   (replace-regexp-in-string "\\[\\-?_erc_[0-9:.]+__---\\]" "" msg)))

(defun my/erc-espeak-process-next ()
  "Procesa el siguiente mensaje de la cola."
  (when my/erc-espeak-msg-queue
    (let ((item (pop my/erc-espeak-msg-queue)))
      (let ((nick (car item))
            (msg-de (cadr item))
            (orig-msg (caddr item)))
        ;; Espeak secuencial: nick, scrieb, mensaje en alemán
        (start-process
         "espeak-seq" nil "bash" "-c"
         (concat
          "espeak -s 135 -p 20 -a 160 -g 3 \"" nick "!\" && "
          "espeak -vde -s 135 -p 20 -a 160 -g 3 \"scrieb!\" && "
          "espeak -vde -s 135 -p 20 -a 160 -g 3 \"" msg-de "!\""))
        ;; Crear imagen con mensaje original + traducción
        (let* ((tempfile (make-temp-file "erc-msg-" nil ".png"))
               (resolution (string-trim
                            (shell-command-to-string
                             "xrandr 2>/dev/null | grep '*' | sed 's/.* \\([0-9]\\+x[0-9]\\+\\).*/\\1/'")))
               (resolution (if (string-empty-p resolution) "800x600" resolution))
               (width (string-to-number (car (split-string resolution "x"))))
               (margin 50)
               (point-size 36)
               ;; limpiar también el mensaje original
               (clean-orig (my/erc-espeak-clean-msg orig-msg))
               (text (concat nick " schrieb " msg-de " »» " clean-orig)))
          (call-process
           "convert" nil nil nil
           "-size" (format "%dx" (- width (* 2 margin)))
           "-background" "black"
           "-fill" "white"
           "-pointsize" (number-to-string point-size)
           "-font" "/usr/share/fonts/liberation/LiberationSans-BoldItalic.ttf"
           "-gravity" "center"
           (concat "caption:" text)
           "-bordercolor" "black"
           "-border" (number-to-string margin)
           tempfile)
          ;; Matar cualquier feh anterior y mostrar nueva imagen
          (ignore-errors (call-process "pkill" nil nil nil "feh"))
          (start-process "feh-msg" nil "feh" "--borderless" tempfile))))))

(defun my/erc-espeak-start-timer ()
  "Inicia un timer que procesa un mensaje cada minuto hasta vaciar la cola."
  (unless (timerp my/erc-espeak-timer)
    (setq my/erc-espeak-timer
          (run-at-time 0 60 #'my/erc-espeak-process-next))))

(defun my/erc-espeak-nick+message-enqueue ()
  "Encola todos los mensajes del buffer de ERC para ser anunciados y mostrados."
  (interactive)
  (when (eq major-mode 'erc-mode)
    (save-excursion
      (goto-char (point-min))

      ;; Recorre todas las cabeceras <nick> o * nick
      (while (re-search-forward "^\\(?:<\\([^>]+\\)>\\|\\* \\([^ ]+\\)\\)\\s-*\\(.*\\)$"
                                (point-max) t)
        (let* ((nick (or (match-string 1) (match-string 2)))
               (orig-msg (match-string 3)))

          ;; Acumular líneas continuadas
          (while (and (not (eobp))
                      (not (looking-at "^\\(?:<[^>]+>\\|\\* [^ ]+\\)")))
            (setq orig-msg
                  (concat orig-msg "\n"
                          (buffer-substring-no-properties
                           (line-beginning-position)
                           (line-end-position))))
            (forward-line 1))

          ;; Limpiar marcas de tiempo
          (let* ((clean-msg (my/erc-espeak-clean-msg orig-msg))

                 ;; Convertir saltos de línea en espacios → mensaje unificado
                 (single-line-msg
                  (string-trim (replace-regexp-in-string "\n+" " " clean-msg)))

                 ;; traducir ya la versión de una sola línea
                 (msg-de
                  (string-trim
                   (shell-command-to-string
                    (concat "$HOME/googletrans/dist/googletrans-de "
                            (shell-quote-argument single-line-msg))))))

            ;; Encolar nick + traducción + mensaje limpio en una sola línea
            (push (list nick msg-de single-line-msg)
                  my/erc-espeak-msg-queue)))))

    ;; Asegura que el timer esté corriendo
    (my/erc-espeak-start-timer)))

(add-hook 'erc-insert-post-hook 'my/erc-espeak-nick+message-enqueue)


;; ============================================================
;; Configuración ERC sin saltos de línea, sin fill, sin wrapping
;; ============================================================

(with-eval-after-load 'erc

  ;; -----------------------------------------------
  ;; Desactivar el módulo que corta texto (erc-fill)
  ;; -----------------------------------------------
  (setq erc-modules (remove 'fill erc-modules))

  (add-hook 'erc-mode-hook
            (lambda ()
              (when (bound-and-true-p erc-fill-mode)
                (erc-fill-mode -1))))

  ;; -----------------------------------------------
  ;; Timestamps con microsegundos
  ;; -----------------------------------------------
  (defun my-erc-setup-timestamps ()
    "Configura timestamps con microsegundos en ERC."
    (erc-timestamp-mode t)
    (setq erc-timestamp-format "[-_erc_%H:%M:%S.%6N__---]"))

  (add-hook 'erc-mode-hook #'my-erc-setup-timestamps)

  ;; -----------------------------------------------
  ;; Evitar cualquier salto de línea o wrapping
  ;; -----------------------------------------------
  (add-hook 'erc-mode-hook
            (lambda ()
              (turn-off-auto-fill)
              (visual-line-mode -1)
              (setq truncate-lines t))))

;; Global, opcional
(add-hook 'erc-mode-hook #'turn-off-auto-fill)
(setq-default auto-fill-function nil)
