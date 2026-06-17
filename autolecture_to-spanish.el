(defvar my/lines-list nil)
(defvar my/current-line-index 0)


;;; ============================================================
;;; Cargar documento
;;; ============================================================

(defun my/load-document-lines (file)
  "Carga todas las líneas del archivo FILE y comienza la reproducción."
  (setq my/lines-list
        (with-temp-buffer
          (insert-file-contents file)
          (split-string (buffer-string) "\n" t)))
  (setq my/current-line-index 0)
  (message "Documento cargado: %s líneas" (length my/lines-list))
  (my/show-next-line))


;;; ============================================================
;;; Mostrar línea siguiente
;;; ============================================================

(defun my/show-next-line ()
  "Muestra la siguiente línea y activa audio automático."
  (if (>= my/current-line-index (length my/lines-list))
      (message "Fin del documento.")
    (let* ((orig (nth my/current-line-index my/lines-list))
           (msg-es (string-trim
                    (shell-command-to-string
                     (concat "$HOME/googletrans/dist/googletrans-es "
		     ;;(concat "echo "
                             (shell-quote-argument orig))))))
      (my/single-panel-and-audio msg-es))))


;;; ============================================================
;;; Panel + audio con avance automático
;;; ============================================================

(defun my/single-panel-and-audio (text)
  "Muestra un único panel con la traducción y avanza al terminar el audio."
  (let ((buf (get-buffer-create "*panel*")))

    ;; Panel único
    (delete-other-windows)
    (set-window-buffer (selected-window) buf)

    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer))

      ;; Configuración visual
      (setq-local buffer-read-only nil
                  truncate-lines nil
                  word-wrap t
                  mode-line-format nil
                  cursor-type nil
                  line-spacing 0.3)

      ;; Insertar texto (traducción)
      (insert (propertize text
                          'face `(:foreground "white"
                                  :background "black"
                                  :height 250)))

      (goto-char (point-min))
      (setq-local buffer-read-only t))

    ;; Generar audio y avanzar automáticamente
    (let* ((escaped (replace-regexp-in-string "%" "%%" text))
           (cmd (format "echo \"%s!\" | /home/user/piper/piper --model /home/user/piper/es_MX-ald-medium.onnx --length_scale 0.7 --sentence_silence 0.1 --output_raw | aplay -r 22050 -f S16_LE -t raw"
			;; last version ↓
			;; (cmd (format "$HOME/pliteratura/dist/pliteratura 'es' '/tmp/last_message.wav' \"%s!\" && mpv --no-video /tmp/last_message.wav"
                        escaped))
           (proc (start-process "pliteratura-auto" nil "bash" "-c" cmd)))

      ;; Sentinel: cuando el audio termina → siguiente línea
      (set-process-sentinel
       proc
       (lambda (_p event)
         (when (string-match-p "finished" event)
           (setq my/current-line-index (1+ my/current-line-index))
           ;; IMPORTANTÍSIMO: postergar ejecución fuera del sentinel
           (run-at-time 1 nil #'my/show-next-line)))))

    (message "")))

(defun pliteratura-play-clipboard ()
  "Ejecuta pliteratura con el texto del portapapeles y reproduce el audio, sin mostrar buffers."
  (interactive)
  (let* ((text (current-kill 0 t))
         (escaped-text (replace-regexp-in-string "%" "%%" text))
         (cmd (format "echo \"%s!\" | $HOME/piper/piper --model $HOME/piper/es_MX-claude-high.onnx --output_file /tmp/last_message.wav && mpv --no-video /tmp/last_message.wav"
		      ;; last version ↓
		      ;; (cmd (format "$HOME/pliteratura/dist/pliteratura 'es' '/tmp/last_message.wav' \"%s!\" && mpv /tmp/last_message.wav"
                      escaped-text)))
    (start-process "pliteratura-play" nil "sh" "-c" cmd)))

(global-set-key (kbd "C-x x x") #'pliteratura-play-clipboard)

(my/load-document-lines "/home/user/literatura/cuatro-historias.txt")
;;(my/load-document-lines "$HOME/literatura/hyperbola-2025-10-20.txt")
;;(my/load-document-lines "$HOME/literatura/guile-ref-part-001.txt")
;;(my/load-document-lines "$HOME/literatura/c-anthk_.txt")
;;(my/load-document-lines "$HOME/literatura/don-quijote.txt")
;;(my/load-document-lines "$HOME/literatura/go-language-especification.txt")
