(defvar my/lines-list nil)
(defvar my/current-line-index 0)

(defun my/load-document-lines (file)
  "Carga todas las líneas del archivo FILE y muestra la primera."
  (setq my/lines-list
        (with-temp-buffer
          (insert-file-contents file)
          (split-string (buffer-string) "\n" t)))
  (setq my/current-line-index 0)
  (message "Documento cargado: %s líneas" (length my/lines-list))
  (my/show-next-line))

(defun my/show-next-line ()
  "Muestra la línea actual y espera interacción del usuario."
  (if (>= my/current-line-index (length my/lines-list))
      (message "Fin del documento.")
    (let* ((orig (nth my/current-line-index my/lines-list))
           (msg-de (string-trim
                    (shell-command-to-string
                     ;; (concat "$HOME/googletrans/dist/googletrans-de "
                     ;;         (shell-quote-argument orig))
		     "echo 'english learning'"
		     ))))
      (my/two-panel-with-controls msg-de orig))))

(defun my/two-panel-with-controls (text1 text2)
  "Muestra panel doble y lanza audio en paralelo.
Teclas:
- SPC siguiente línea
- q salir del bucle completamente"
  (let* ((buf1 (get-buffer-create "*panel-1*"))
         (buf2 (get-buffer-create "*panel-2*"))
         (keymap (let ((map (make-sparse-keymap)))
                   ;; q salir completamente
                   (define-key map (kbd "q")
                     `(lambda ()
                        (interactive)
                        (kill-buffer ,buf1)
                        (kill-buffer ,buf2)
                        (delete-other-windows)
                        (setq my/current-line-index (length my/lines-list))))
                   ;; SPC siguiente línea
                   (define-key map (kbd "SPC")
                     `(lambda ()
                        (interactive)
                        (kill-buffer ,buf1)
                        (kill-buffer ,buf2)
                        (delete-other-windows)
                        (setq my/current-line-index (1+ my/current-line-index))
                        ;; mostrar la siguiente línea
                        (my/show-next-line)))
                   map)))

    ;; Crear paneles
    (cl-labels
        ((setup-panel (buf text bg)
           (with-current-buffer buf
             (erase-buffer)
             (setq-local buffer-read-only nil
                         truncate-lines nil
			 word-wrap 1
                         mode-line-format nil
                         header-line-format nil
                         cursor-type nil
                         line-spacing 0.3)
             (insert (propertize text
                                 'face `(:foreground "white"
                                         :background ,bg
                                         :height 250)))
             (goto-char (point-min))
             (setq-local buffer-read-only t)
             (use-local-map keymap))))
      (setup-panel buf1 text1 "black")
      (setup-panel buf2 text2 "gray10"))

    ;; Mostrar paneles
    (delete-other-windows)
    (let ((win1 (selected-window)))
      (set-window-buffer win1 buf1)
      (set-window-buffer (split-window-vertically) buf2)
      (select-window win1))

    (message "Presiona SPC para avanzar, q para salir")))

(defun pliteratura-play-clipboard ()
  "Ejecuta pliteratura con el texto del portapapeles y reproduce el audio, sin mostrar buffers."
  (interactive)
  (let* ((text (current-kill 0 t))
         (escaped-text (replace-regexp-in-string "%" "%%" text))
         (cmd (format "$HOME/pliteratura/dist/pliteratura 'en' '/tmp/last_message.wav' \"%s!\" && mpv /tmp/last_message.wav"
                      escaped-text)))
    (start-process "pliteratura-play" nil "sh" "-c" cmd)))

(global-set-key (kbd "C-x x x") #'pliteratura-play-clipboard)

(defun my/load-document-lines-simil (pattern)
  "Carga todas las líneas de los archivos que coincidan con PATTERN en $HOME/literatura/."
  ;; convertir comodines tipo '*' a regex
  (let* ((regex (replace-regexp-in-string "\\*" ".*" pattern))
         (files (directory-files "$HOME/literatura-to-es" t regex)))
    ;; cargar cada archivo
    (mapcar #'my/load-document-lines files)))

;; Ejemplo de uso
;;(my/load-document-lines-simil "Experienced-Associate--*-m-f-d--*.txt")
;; otros patrones
(my/load-document-lines-simil "c-anthk_.en.txt")
;; (my/load-document-lines-simil "ds.*.txt")
;; (my/load-document-lines-simil "g.*.txt")
;; (my/load-document-lines-simil "chatgpt-Experienced-Associate--*.txt")
;; (my/load-document-lines-simil "speech-cgpt.Experienced-Associate--*.txt")
;; (my/load-document-lines-simil "speech-ds.Experienced-Associate--*.txt")
;; (my/load-document-lines-simil "speech-g.Experienced-Associate--*.txt")
