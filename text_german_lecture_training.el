;; Requeriments
;; Source in → wget https://saravia.org/monoliths-llm/plain/piper.tar.gz ← you could download an compile too
;; ^ require on your ~ ($HOME)
;; git clone http://saravia.org/Literatur.git
;; ^ require on your ~ ($HOME)
;; All the source is readable and compilable

(defvar my/lines-list nil)
(defvar my/lines-list-es nil)
(defvar my/current-line-index 0)

(defun my/load-document-lines (file-de file-es)
  "Carga todas las líneas de FILE-DE (alemán) y FILE-ES (español)."
  (setq my/lines-list
        (with-temp-buffer
          (insert-file-contents file-de)
          (split-string (buffer-string) "\n")))
  (setq my/lines-list-es
        (with-temp-buffer
          (insert-file-contents file-es)
          (split-string (buffer-string) "\n")))
  (setq my/current-line-index 0)
  (message "Documentos cargados. DE: %d líneas, ES: %d líneas" 
           (length my/lines-list) (length my/lines-list-es))
  (my/show-next-line))

(defun my/show-next-line ()
  "Muestra la línea actual del alemán y su correspondiente en español."
  (if (>= my/current-line-index (length my/lines-list))
      (message "Fin del documento.")
    (let ((orig (nth my/current-line-index my/lines-list))
          (msg-es (or (nth my/current-line-index my/lines-list-es) "")))
      (my/two-panel-with-controls orig msg-es))))

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

    ;; Reproducir audio en paralelo
    (start-process
     "pliteratura-audio"
     nil "bash" "-c"
     (format "echo \"%s!\" | $HOME/piper/piper --model $HOME/piper/de_DE-thorsten-high.onnx --output_file /tmp/last_message.wav && mpv --no-video --volume=120 /tmp/last_message.wav"
	     ;; (format "$HOME/pliteratura/dist/pliteratura 'de' '/tmp/last_message.wav' \"%s!\" && mpv /tmp/last_message.wav"
             (replace-regexp-in-string "%" "%%" text1)))

    (message "Presiona SPC para avanzar, q para salir")))

(defun pliteratura-play-clipboard ()
  "Ejecuta pliteratura con el texto del portapapeles y reproduce el audio, sin mostrar buffers."
  (interactive)
  (let* ((text (current-kill 0 t))
         (escaped-text (replace-regexp-in-string "%" "%%" text))
         (cmd (format "echo \"%s!\" | $HOME/piper/piper --model $HOME/piper/de_DE-thorsten-high.onnx --output_file /tmp/last_message.wav && mpv --no-video --volume=120 /tmp/last_message.wav"
                      escaped-text)))
    (message escaped-text)
    (start-process "pliteratura-play" nil "sh" "-c" cmd)))

(global-set-key (kbd "M-0") #'pliteratura-play-clipboard)

(my/load-document-lines "../Literatur/alicia.A1.de.txt" 
                       "../Literatur/alicia.A1.de.literal.es.txt")


;;(my/load-document-lines "$HOME/literatura/c-anthk-part-3_.txt")
;; (my/load-document-lines "$HOME/literatura/COMMON-LISP-part-002.txt")
