;;; alt_tab_external_buffers.el --- Integración de ventanas externas X11 como buffers de Emacs

;;; Commentary:
;; Este módulo sincroniza las ventanas de X11 no-Emacs (obtenidas por el gestor de ventanas
;; alt_tab_maximize_emacs-buffer_only) como buffers en Emacs.
;; 
;; Permite cambiar a cualquier ventana externa haciendo `C-x b <NombreVentana> RET`.
;; En cuanto el buffer de la ventana externa se hace presente en pantalla, se activa la ventana
;; real en el sistema (vía xdotool) y Emacs restaura inmediatamente el buffer previo.

;;; Code:

(defgroup external-windows nil
  "Gestión de ventanas externas como buffers de Emacs."
  :group 'convenience)

(defcustom my-external-buffer-format "*Ext: %s*"
  "Formato para los nombres de buffers de ventanas externas. %s se reemplaza por el título de la ventana."
  :type 'string
  :group 'external-windows)

(defvar-local my-external-window-id nil
  "ID de la ventana X11 asociada a este buffer.")

(defvar my-last-real-buffer nil
  "Último buffer normal (no externo) visitado por el usuario.")

(defvar my-external-windows-hash (make-hash-table :test 'equal)
  "Mapeo de ID de ventana X11 a objeto buffer.")

(defun my-update-last-real-buffer ()
  "Registra el último buffer activo que no sea una ventana externa ni el minibuffer."
  (unless (or (bound-and-true-p my-external-window-id)
              (minibufferp)
              (string-prefix-p " " (buffer-name)))
    (setq my-last-real-buffer (current-buffer))))

(defun my-activate-external-window-id (win-id)
  "Ejecuta xdotool para activar la ventana con ID WIN-ID."
  (call-process "xdotool" nil 0 nil "windowactivate" (format "%s" win-id)))

(defun my-check-and-trigger-external-windows (&optional frame)
  "Verifica si alguna ventana de Emacs muestra un buffer externo y dispara la ventana real."
  (dolist (win (window-list frame))
    (let ((buf (window-buffer win)))
      (when (and (buffer-live-p buf)
                 (buffer-local-value 'my-external-window-id buf))
        (let ((win-id (buffer-local-value 'my-external-window-id buf))
              (title (buffer-name buf))
              (fallback (if (and my-last-real-buffer (buffer-live-p my-last-real-buffer))
                            my-last-real-buffer
                          (other-buffer buf t))))
          ;; Restaurar el buffer anterior en la ventana de Emacs
          (set-window-buffer win fallback)
          ;; Activar la ventana real externa en X11
          (my-activate-external-window-id win-id)
          (message "Ventana externa activada: %s" title))))))

(defun my-sync-external-window-buffers ()
  "Sincroniza los buffers individuales de Emacs con la lista /tmp/emacs_non_emacs_windows."
  (interactive)
  (let ((file "/tmp/emacs_non_emacs_windows")
        (current-ids (make-hash-table :test 'equal)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                 (parts (split-string line "\t")))
            (when (>= (length parts) 2)
              (let* ((win-id (nth 0 parts))
                     (win-title (nth 1 parts))
                     (buf-name (format my-external-buffer-format win-title))
                     (existing-buf (gethash win-id my-external-windows-hash))
                     (buf (get-buffer buf-name)))
                (puthash win-id t current-ids)
                ;; Si la ventana cambió de título, eliminar el buffer con el título viejo
                (when (and existing-buf
                           (buffer-live-p existing-buf)
                           (not (string= (buffer-name existing-buf) buf-name)))
                  (kill-buffer existing-buf))
                (if (and buf (buffer-live-p buf))
                    (with-current-buffer buf
                      (setq-local my-external-window-id win-id))
                  (setq buf (get-buffer-create buf-name))
                  (with-current-buffer buf
                    (setq-local my-external-window-id win-id)
                    (let ((inhibit-read-only t))
                      (erase-buffer)
                      (insert (format "=== VENTANA EXTERNA X11 ===\nID: %s\nTítulo: %s\n\nEste buffer representa una ventana del sistema.\nAl ser visualizado, Emacs enfoca la ventana real y regresa al buffer anterior."
                                      win-id win-title))
                      (read-only-mode 1))))
                (puthash win-id buf my-external-windows-hash))))
          (forward-line 1))))
    ;; Eliminar buffers de ventanas cerradas
    (maphash (lambda (win-id buf)
               (unless (gethash win-id current-ids)
                 (when (buffer-live-p buf)
                   (kill-buffer buf))
                 (remhash win-id my-external-windows-hash)))
             my-external-windows-hash)))

;; Integración con el buffer *External Windows* existente
(defun my-activate-window-at-point ()
  "Activa la ventana seleccionada en la línea actual."
  (interactive)
  (let ((id (get-text-property (point) 'window-id)))
    (unless id
      (save-excursion
        (beginning-of-line)
        (when (re-search-forward "\\[ \\([0-9]+\\) \\]" (line-end-position) t)
          (setq id (match-string 1)))))
    (if id
        (progn
          (my-activate-external-window-id id)
          (message "Ventana %s activada" id))
      (message "No hay ID de ventana en esta línea"))))

(define-derived-mode external-windows-mode special-mode "External-Windows"
  "Modo interactivo para el buffer de ventanas externas."
  (define-key external-windows-mode-map (kbd "RET") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<return>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<mouse-2>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<down-mouse-1>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "g") #'my-update-external-windows))

(defun my-update-external-windows ()
  "Actualiza el buffer *External Windows* y los buffers individuales."
  (interactive)
  (my-sync-external-window-buffers)
  (let ((buf (get-buffer-create "*External Windows*"))
        (file "/tmp/emacs_non_emacs_windows"))
    (when (file-exists-p file)
      (with-current-buffer buf
        (unless (eq major-mode 'external-windows-mode)
          (external-windows-mode))
        (let ((inhibit-read-only t)
              (old-pos (point)))
          (erase-buffer)
          (insert "=== VENTANAS ABIERTAS (FUERA DE EMACS) ===\n")
          (insert "Presiona ENTER en cualquier línea para cambiar a esa ventana.\n")
          (insert "También puedes usar C-x b <NombreVentana> para ir directamente.\n\n")
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (while (not (eobp))
              (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                     (parts (split-string line "\t")))
                (when (>= (length parts) 2)
                  (let* ((win-id (nth 0 parts))
                         (win-title (nth 1 parts))
                         (line-text (format "[ %s ] %s" win-id win-title))
                         (start (point)))
                    (with-current-buffer buf
                      (insert-button line-text
                                     'action (lambda (btn)
                                               (let ((id (button-get btn 'window-id)))
                                                 (when id
                                                   (my-activate-external-window-id id))))
                                     'window-id win-id
                                     'follow-link t)
                      (add-text-properties start (point) `(window-id ,win-id))
                      (insert "\n")))))
              (forward-line 1)))
          (goto-char (max (point-min) (min old-pos (point-max)))))))))

(defvar my-external-windows-timer nil
  "Timer para la actualización periódica de ventanas externas.")

(defvar my-external-windows-thread nil
  "Hilo para la actualización de ventanas externas.")

(defun my-start-external-windows-tracker ()
  "Inicia la sincronización periódica de ventanas externas y hooks en Emacs."
  (interactive)
  ;; Hooks para cambiar de buffer automáticamente al seleccionar un buffer externo
  (add-hook 'post-command-hook #'my-update-last-real-buffer)
  (add-hook 'post-command-hook #'my-check-and-trigger-external-windows)
  (add-hook 'window-state-change-hook #'my-check-and-trigger-external-windows)

  ;; Usamos timer o hilo para rastrear las ventanas continuamente
  (unless (or my-external-windows-timer
              (and my-external-windows-thread (thread-live-p my-external-windows-thread)))
    (if (fboundp 'make-thread)
        (setq my-external-windows-thread
              (make-thread
               (lambda ()
                 (while t
                   (ignore-errors (my-update-external-windows))
                   (sleep-for 1)))
               "external-windows-tracker"))
      (setq my-external-windows-timer
            (run-with-timer 0 1 #'my-update-external-windows)))
    (message "Rastreador de ventanas externas y buffers automáticos iniciado.")))

(defun my-stop-external-windows-tracker ()
  "Detiene el rastreador de ventanas externas."
  (interactive)
  (remove-hook 'post-command-hook #'my-update-last-real-buffer)
  (remove-hook 'post-command-hook #'my-check-and-trigger-external-windows)
  (remove-hook 'window-state-change-hook #'my-check-and-trigger-external-windows)
  (when my-external-windows-timer
    (cancel-timer my-external-windows-timer)
    (setq my-external-windows-timer nil))
  (when (and my-external-windows-thread (thread-live-p my-external-windows-thread))
    (thread-signal my-external-windows-thread 'quit nil)
    (setq my-external-windows-thread nil))
  (message "Rastreador de ventanas externas detenido."))

;; Iniciar automáticamente al cargar
(my-start-external-windows-tracker)

(provide 'alt_tab_external_buffers)
