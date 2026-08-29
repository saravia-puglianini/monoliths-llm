;;; registro-diario-emacs.el --- Registro Diario de Horas Jira en Emacs Buffer -*- lexical-binding: t -*-

;;; Commentary:
;; Modo interactivo completo en buffer Emacs para gestionar y registrar
;; horas en Jira, ver tareas asignadas, historias de usuario, navegar por días,
;; insertar registros locales/directos e imprimir PDF.

(require 'json)
(require 'url)
(require 'url-http)
(require 'cl-lib)

(defgroup registro-diario nil
  "Gestión de registro diario de horas Jira."
  :group 'tools)

(defcustom registro-diario-config-file "~/.justificar/jira_config"
  "Ruta del archivo de configuración de credenciales Jira."
  :type 'string
  :group 'registro-diario)

(defcustom registro-diario-csv-file "~/.justificar/justificar.csv"
  "Ruta del archivo CSV de registro."
  :type 'string
  :group 'registro-diario)

(defcustom registro-diario-state-file "~/.justificar/registro-diario-yad.json"
  "Ruta del estado JSON local."
  :type 'string
  :group 'registro-diario)

;; Variables de estado interno
(defvar registro-diario--config nil)
(defvar registro-diario--current-day (format-time-string "%Y-%m-%d"))
(defvar registro-diario--issues nil)
(defvar registro-diario--worklogs-cache (make-hash-table :test 'equal))
(defvar registro-diario--selected-story nil)
(defvar registro-diario--filter-query "")
(defvar registro-diario--selected-hours 1.0)
(defvar registro-diario--selected-activity "Refinamiento")
(defvar registro-diario--loading nil)

(defun registro-diario--read-config ()
  "Lee el archivo ~/.justificar/jira_config."
  (let ((cfg (make-hash-table :test 'equal))
        (path (expand-file-name registro-diario-config-file)))
    (unless (file-exists-p path)
      (error "No existe el archivo de configuración: %s" path))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (string-trim (buffer-substring-no-properties (point) (line-end-position)))))
          (when (and (not (string-prefix-p "#" line))
                     (string-match "^\\([^=]+\\)=\\(.*\\)$" line))
            (let ((key (string-trim (match-string 1 line)))
                  (val (string-trim (match-string 2 line) "[\"']" "[\"']")))
              (puthash key val cfg))))
        (forward-line 1)))
    (unless (and (gethash "JIRA_DOMAIN" cfg)
                 (gethash "JIRA_EMAIL" cfg)
                 (gethash "JIRA_API_TOKEN" cfg))
      (error "Faltan credenciales en ~/.justificar/jira_config"))
    (setq registro-diario--config cfg)))

(defun registro-diario--jira-request (path &optional method payload)
  "Realiza una petición a la API REST de Jira de forma síncrona en Elisp."
  (unless registro-diario--config
    (registro-diario--read-config))
  (let* ((domain (directory-file-name (gethash "JIRA_DOMAIN" registro-diario--config)))
         (api-base (gethash "_API_BASE" registro-diario--config domain))
         (email (gethash "JIRA_EMAIL" registro-diario--config))
         (token (gethash "JIRA_API_TOKEN" registro-diario--config))
         (auth-header (concat "Basic " (base64-encode-string (concat email ":" token) t)))
         (url-request-method (or method "GET"))
         (url-request-extra-headers
          `(("Authorization" . ,auth-header)
            ("Accept" . "application/json")
            ("Content-Type" . "application/json")))
         (url-request-data (when payload (encode-coding-string (json-encode payload) 'utf-8)))
         (target-url (concat api-base path))
         (buffer (url-retrieve-synchronously target-url t t 15)))
    (unless buffer
      (error "No se pudo conectar con Jira: %s" target-url))
    (with-current-buffer buffer
      (goto-char (point-min))
      (re-search-forward "\r?\n\r?\n" nil t)
      (let ((json-object-type 'hash-table)
            (json-array-type 'list)
            (json-key-type 'string))
        (prog1
            (condition-case nil
                (json-read)
              (error (buffer-substring-no-properties (point) (point-max))))
          (kill-buffer buffer))))))

(defun registro-diario--configure-api ()
  "Configura _ACCOUNT_ID y _API_BASE si es necesario."
  (unless (gethash "_ACCOUNT_ID" registro-diario--config)
    (condition-case nil
        (let ((me (registro-diario--jira-request "/rest/api/3/myself")))
          (puthash "_ACCOUNT_ID" (gethash "accountId" me) registro-diario--config))
      (error
       ;; Intentar tenant_info para tokens con alcance
       (let* ((domain (directory-file-name (gethash "JIRA_DOMAIN" registro-diario--config)))
              (tenant-url (concat domain "/_edge/tenant_info"))
              (buf (url-retrieve-synchronously tenant-url t t 15)))
         (when buf
           (with-current-buffer buf
             (goto-char (point-min))
             (re-search-forward "\r?\n\r?\n" nil t)
             (let* ((info (json-read-from-string (buffer-substring-no-properties (point) (point-max))))
                    (cloud-id (cdr (assoc 'cloudId info))))
               (puthash "_API_BASE" (concat "https://api.atlassian.com/ex/jira/" cloud-id) registro-diario--config)
               (let ((me (registro-diario--jira-request "/rest/api/3/myself")))
                 (puthash "_ACCOUNT_ID" (gethash "accountId" me) registro-diario--config)))
             (kill-buffer buf))))))))

(defun registro-diario--fetch-issues ()
  "Consulta todas las tareas e historias asignadas."
  (registro-diario--configure-api)
  (let* ((jql-tasks "(assignee = currentUser() OR worklogAuthor = currentUser()) AND (statusCategory != Done OR status = \"En medición\" OR sprint in openSprints()) AND issuetype in (Task, Tarea, \"Sub-task\", Subtarea, Correctivos, \"Error en producción\", Incidencias) ORDER BY updated DESC")
         (jql-stories "sprint in openSprints() AND issuetype in (Story, \"Historia de usuario\", Historia, Hito) ORDER BY key ASC")
         (q-tasks (concat "/rest/api/3/search/jql?jql=" (url-hexify-string jql-tasks) "&maxResults=100&fields=key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks"))
         (q-stories (concat "/rest/api/3/search/jql?jql=" (url-hexify-string jql-stories) "&maxResults=150&fields=key,summary,project,parent,status,timespent,aggregatetimespent,issuetype,issuelinks"))
         (res-t (registro-diario--jira-request q-tasks))
         (res-s (registro-diario--jira-request q-stories))
         (all-issues '())
         (seen (make-hash-table :test 'equal)))
    (dolist (res (list res-t res-s))
      (when (hash-table-p res)
        (dolist (it (gethash "issues" res))
          (let ((k (gethash "key" it)))
            (unless (gethash k seen)
              (puthash k t seen)
              (let* ((fields (gethash "fields" it))
                     (project (gethash "project" fields))
                     (parent (gethash "parent" fields))
                     (p-fields (when parent (gethash "fields" parent)))
                     (itype (gethash "name" (gethash "issuetype" fields)))
                     (sec (or (gethash "timespent" fields) (gethash "aggregatetimespent" fields) 0))
                     (links (gethash "issuelinks" fields))
                     (linked-stories '())
                     (linked-tasks '()))
                (dolist (l links)
                  (let ((inward (gethash "inwardIssue" l))
                        (outward (gethash "outwardIssue" l)))
                    (dolist (other (list inward outward))
                      (when other
                        (let* ((okey (gethash "key" other))
                               (otype (gethash "name" (gethash "issuetype" (gethash "fields" other)))))
                          (if (member otype '("Historia de usuario" "Story" "Historia"))
                              (push okey linked-stories)
                            (push okey linked-tasks)))))))
                (push (list :key k
                            :summary (gethash "summary" fields)
                            :project (if project (gethash "name" project) "-")
                            :project-key (if project (gethash "key" project) "")
                            :parent-key (if parent (gethash "key" parent) "-")
                            :parent (if p-fields (gethash "summary" p-fields) "-")
                            :status (gethash "name" (gethash "status" fields))
                            :hours (/ (float sec) 3600.0)
                            :type itype
                            :linked-stories linked-stories
                            :linked-tasks linked-tasks)
                      all-issues)))))))
    (setq registro-diario--issues (nreverse all-issues))))

(defun registro-diario--fetch-worklogs (target-day)
  "Obtiene los worklogs reales del usuario para una fecha."
  (registro-diario--configure-api)
  (let* ((account-id (gethash "_ACCOUNT_ID" registro-diario--config))
         (jql (format "worklogAuthor = currentUser() AND worklogDate = \"%s\" ORDER BY updated DESC" target-day))
         (q (concat "/rest/api/3/search/jql?jql=" (url-hexify-string jql) "&maxResults=100&fields=key,summary,issuetype,parent,issuelinks"))
         (res (registro-diario--jira-request q))
         (items '()))
    (when (hash-table-p res)
      (dolist (issue (gethash "issues" res))
        (let* ((k (gethash "key" issue))
               (fields (gethash "fields" issue))
               (summary (gethash "summary" fields))
               (w-data (condition-case nil
                           (registro-diario--jira-request (format "/rest/api/3/issue/%s/worklog?maxResults=500" (url-hexify-string k)))
                         (error nil))))
          (when (hash-table-p w-data)
            (dolist (w (gethash "worklogs" w-data))
              (when (and (or (not account-id) (string= (gethash "accountId" (gethash "author" w)) account-id))
                         (string-prefix-p target-day (or (gethash "started" w) "")))
                (let* ((sec (or (gethash "timeSpentSeconds" w) 0))
                       (comm (gethash "comment" w))
                       (comment-text (if (stringp comm) comm "Trabajo en tarea")))
                  (push (list :key k
                              :summary summary
                              :hours (/ (float sec) 3600.0)
                              :activity comment-text
                              :worklog-id (gethash "id" w))
                        items))))))))
    (puthash target-day (nreverse items) registro-diario--worklogs-cache)))

(defun registro-diario--format-hours (hours)
  "Formatea horas flotantes a texto conciso."
  (let* ((h (floor hours))
         (m (round (* (- hours h) 60))))
    (if (> m 0)
        (if (> h 0) (format "%dh %dmin" h m) (format "%dmin" m))
      (format "%dh" h))))

;;; ----------------------------------------------------------------------------
;;; MODO Y RENDERIZADO DEL BUFFER INTERACTIVO
;;; ----------------------------------------------------------------------------

(defvar registro-diario-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") 'kill-current-buffer)
    (define-key map (kbd "g") 'registro-diario-refresh)
    (define-key map (kbd "p") 'registro-diario-prev-day)
    (define-key map (kbd "n") 'registro-diario-next-day)
    (define-key map (kbd "t") 'registro-diario-today)
    (define-key map (kbd "s") 'registro-diario-search)
    (define-key map (kbd "c") 'registro-diario-clear-story)
    (define-key map (kbd "i") 'registro-diario-register-direct)
    (define-key map (kbd "l") 'registro-diario-insert-local)
    (define-key map (kbd "P") 'registro-diario-print-pdf)
    (define-key map (kbd "o") 'registro-diario-open-jira)
    (define-key map (kbd "RET") 'registro-diario-enter-action)
    (define-key map (kbd "+") 'registro-diario-inc-hours)
    (define-key map (kbd "-") 'registro-diario-dec-hours)
    (define-key map (kbd "a") 'registro-diario-set-activity)
    map)
  "Keymap para el modo `registro-diario-mode'.")

(define-derived-mode registro-diario-mode special-mode "Jira-Registro-Diario"
  "Modo interactivo en buffer Emacs para gestión de registro diario de horas Jira."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defun registro-diario--insert-button (label action &optional face)
  "Inserta un botón/link interactivo en el buffer."
  (let ((start (point)))
    (insert label)
    (make-text-button start (point)
                      'action action
                      'follow-link t
                      'face (or face 'custom-button))))

(defun registro-diario-render ()
  "Renderiza la interfaz completa en el buffer *Jira-Registro-Diario*."
  (let ((buf (get-buffer-create "*Jira-Registro-Diario*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t)
            (orig-pos (point)))
        (erase-buffer)
        (registro-diario-mode)

        ;; CABECERA SUPERIOR
        (insert (propertize "========================================================================================================\n" 'face 'font-lock-comment-face))
        (insert (format "  EMACS::JIRA-HOURS-CONSOLE  |  FECHA: %s  |  ESTADO: " (propertize registro-diario--current-day 'face 'font-lock-keyword-face)))

        (let* ((jira-logs (gethash registro-diario--current-day registro-diario--worklogs-cache '()))
               (jira-total (cl-loop for w in jira-logs sum (plist-get w :hours)))
               (target-hours 8.0)
               (min-hours 6.5)
               (max-hours 10.5))
          (cond
           ((< jira-total min-hours)
            (insert (propertize (format "[-] FALTAN %s" (registro-diario--format-hours (- min-hours jira-total))) 'face 'font-lock-warning-face)))
           ((<= jira-total max-hours)
            (insert (propertize (format "[OK] %s JORNADA COMPLETA" (registro-diario--format-hours jira-total)) 'face 'font-lock-function-name-face)))
           (t
            (insert (propertize (format "[!] SOBREPASO %s" (registro-diario--format-hours (- jira-total max-hours))) 'face 'font-lock-warning-face))))

          (insert (format "  (Total Jira: %s)\n" (registro-diario--format-hours jira-total))))
        (insert (propertize "========================================================================================================\n\n" 'face 'font-lock-comment-face))

        ;; BARRA DE COMANDOS / ACCIONES RÁPIDAS
        (insert "  NAVEGAR: ")
        (registro-diario--insert-button "[ < Dia Anterior (p) ]" (lambda (_) (registro-diario-prev-day)))
        (insert "  ")
        (registro-diario--insert-button "[ Hoy (t) ]" (lambda (_) (registro-diario-today)))
        (insert "  ")
        (registro-diario--insert-button "[ Dia Siguiente > (n) ]" (lambda (_) (registro-diario-next-day)))
        (insert "   |   ACCIONES: ")
        (registro-diario--insert-button "[ Sincronizar (g) ]" (lambda (_) (registro-diario-refresh)))
        (insert "  ")
        (registro-diario--insert-button "[ Imprimir PDF (P) ]" (lambda (_) (registro-diario-print-pdf)))
        (insert "\n\n")

        ;; PANEL DE CONFIGURACIÓN DE REGISTRO
        (insert (propertize "  +-- [ CONFIGURACION DE REGISTRO ] ----------------------------------------------------------------------+\n" 'face 'font-lock-type-face))
        (insert (format "  |  TIEMPO: %s  " (propertize (format "%s" (registro-diario--format-hours registro-diario--selected-hours)) 'face 'font-lock-constant-face)))
        (registro-diario--insert-button "[ -0.5h (-) ]" (lambda (_) (registro-diario-dec-hours)))
        (insert " ")
        (registro-diario--insert-button "[ +0.5h (+) ]" (lambda (_) (registro-diario-inc-hours)))
        (insert (format "   |   ACTIVIDAD: %s  " (propertize registro-diario--selected-activity 'face 'font-lock-string-face)))
        (registro-diario--insert-button "[ Cambiar (a) ]" (lambda (_) (registro-diario-set-activity)))
        (insert "\n")
        (insert (format "  |  HISTORIA SELECCIONADA: %s  "
                        (if registro-diario--selected-story
                            (propertize (format "%s (filtra tareas vinculadas)" registro-diario--selected-story) 'face 'font-lock-variable-name-face)
                          (propertize "(ninguna - viendo todas las tareas)" 'face 'font-lock-comment-face))))
        (when registro-diario--selected-story
          (registro-diario--insert-button "[ Quitar Filtro HU (c) ]" (lambda (_) (registro-diario-clear-story))))
        (insert "\n")
        (insert (propertize "  +-------------------------------------------------------------------------------------------------------+\n\n" 'face 'font-lock-type-face))

        ;; TABLA 1: TAREAS ASIGNADAS
        (let* ((all-tasks (cl-remove-if (lambda (it) (member (plist-get it :type) '("Historia de usuario" "Story" "Historia")))
                                        registro-diario--issues))
               (selected-story-item (cl-find-if (lambda (it) (string= (plist-get it :key) registro-diario--selected-story))
                                                registro-diario--issues))
               (linked-keys (when selected-story-item (plist-get selected-story-item :linked-tasks)))
               (filtered-tasks (cl-remove-if-not
                                (lambda (task)
                                  (and (or (not registro-diario--selected-story)
                                           (member (plist-get task :key) linked-keys)
                                           (member registro-diario--selected-story (plist-get task :linked-stories)))
                                       (or (string-empty-p registro-diario--filter-query)
                                           (string-match-p (regexp-quote (downcase registro-diario--filter-query))
                                                           (downcase (format "%s %s %s" (plist-get task :key) (plist-get task :summary) (plist-get task :status)))))))
                                all-tasks)))

          (insert (propertize (format "  == [ TAREAS ASIGNADAS (%d) ] ==========================================================================\n" (length filtered-tasks)) 'face 'font-lock-keyword-face))
          (insert (propertize (format "  %-12s | %-16s | %-8s | %-60s\n" "CLAVE" "ESTADO" "HORAS" "RESUMEN DE TAREA") 'face 'font-lock-comment-face))
          (insert (propertize "  --------------------------------------------------------------------------------------------------------\n" 'face 'font-lock-comment-face))

          (if (null filtered-tasks)
              (insert "  (No hay tareas que coincidan con la seleccion o filtro)\n")
            (dolist (task filtered-tasks)
              (let* ((key (plist-get task :key))
                     (st (substring (format "%-16s" (plist-get task :status)) 0 16))
                     (hrs (format "%-8s" (registro-diario--format-hours (plist-get task :hours))))
                     (sum (plist-get task :summary))
                     (line-start (point)))
                (insert "  ")
                (registro-diario--insert-button (format "%-12s" key)
                                                (lambda (_) (registro-diario--action-on-task key sum)))
                (insert (format " | %s | %s | %s\n"
                                (propertize st 'face 'font-lock-type-face)
                                (propertize hrs 'face 'font-lock-constant-face)
                                sum))
                (put-text-property line-start (point) 'registro-task task)))))
        (insert "\n")

        ;; TABLA 2: HISTORIAS DE USUARIO
        (let* ((stories (cl-remove-if-not (lambda (it) (member (plist-get it :type) '("Historia de usuario" "Story" "Historia")))
                                          registro-diario--issues)))
          (insert (propertize (format "  == [ HISTORIAS DE USUARIO SPRINT (%d) ] ================================================================\n" (length stories)) 'face 'font-lock-keyword-face))
          (insert (propertize (format "  %-12s | %-16s | %-70s\n" "CLAVE" "ESTADO" "TITULO DE HISTORIA") 'face 'font-lock-comment-face))
          (insert (propertize "  --------------------------------------------------------------------------------------------------------\n" 'face 'font-lock-comment-face))

          (dolist (story stories)
            (let* ((key (plist-get story :key))
                   (st (substring (format "%-16s" (plist-get story :status)) 0 16))
                   (sum (plist-get story :summary))
                   (is-sel (string= key registro-diario--selected-story))
                   (line-start (point)))
              (insert (if is-sel " *" "  "))
              (registro-diario--insert-button (format "%-12s" key)
                                              (lambda (_) (registro-diario--action-on-story key sum)))
              (insert (format " | %s | %s\n"
                              (propertize st 'face 'font-lock-type-face)
                              (if is-sel (propertize sum 'face 'font-lock-warning-face) sum)))
              (put-text-property line-start (point) 'registro-story story))))
        (insert "\n")

        ;; TABLA 3: WORKLOGS DE LA FECHA
        (let ((worklogs (gethash registro-diario--current-day registro-diario--worklogs-cache '())))
          (insert (propertize (format "  == [ REGISTROS DE TRABAJO JIRA DEL %s (%d) ] =======================================\n" registro-diario--current-day (length worklogs)) 'face 'font-lock-keyword-face))
          (insert (propertize (format "  %-12s | %-8s | %-24s | %-50s\n" "CLAVE" "HORAS" "ACTIVIDAD" "TAREA") 'face 'font-lock-comment-face))
          (insert (propertize "  --------------------------------------------------------------------------------------------------------\n" 'face 'font-lock-comment-face))
          (if (null worklogs)
              (insert "  (Sin registros de horas en Jira para esta fecha)\n")
            (dolist (w worklogs)
              (let ((k (plist-get w :key))
                    (h (format "%-8s" (registro-diario--format-hours (plist-get w :hours))))
                    (act (substring (format "%-24s" (plist-get w :activity)) 0 24))
                    (sum (plist-get w :summary)))
                (insert "  ")
                (registro-diario--insert-button (format "%-12s" k)
                                                (lambda (_) (browse-url (format "%s/browse/%s" (directory-file-name (gethash "JIRA_DOMAIN" registro-diario--config)) k))))
                (insert (format " | %s | %s | %s\n"
                                (propertize h 'face 'font-lock-constant-face)
                                (propertize act 'face 'font-lock-string-face)
                                sum))))))

        (insert "\n  [Atajos: 'g' recargar, 'p/n' cambiar dia, '+/-' horas, 'a' actividad, 'i' registrar, 'P' PDF, 'q' salir]\n")
        (goto-char (min orig-pos (point-max))))))
  (pop-to-buffer "*Jira-Registro-Diario*"))

;;; ----------------------------------------------------------------------------
;;; COMANDOS INTERACTIVOS
;;; ----------------------------------------------------------------------------

(defun registro-diario-refresh ()
  "Recarga incidencias y worklogs desde Jira."
  (interactive)
  (message "Sincronizando con Jira...")
  (registro-diario--fetch-issues)
  (registro-diario--fetch-worklogs registro-diario--current-day)
  (registro-diario-render)
  (message "Sincronización completada."))

(defun registro-diario-prev-day ()
  "Retrocede al día anterior."
  (interactive)
  (let* ((time (date-to-time (concat registro-diario--current-day " 12:00:00")))
         (prev (time-subtract time (days-to-time 1))))
    (setq registro-diario--current-day (format-time-string "%Y-%m-%d" prev))
    (unless (gethash registro-diario--current-day registro-diario--worklogs-cache)
      (registro-diario--fetch-worklogs registro-diario--current-day))
    (registro-diario-render)))

(defun registro-diario-next-day ()
  "Avanza al día siguiente."
  (interactive)
  (let* ((time (date-to-time (concat registro-diario--current-day " 12:00:00")))
         (next (time-add time (days-to-time 1)))
         (next-str (format-time-string "%Y-%m-%d" next))
         (today-str (format-time-string "%Y-%m-%d")))
    (if (string> next-str today-str)
        (message "No se puede avanzar más allá del día de hoy.")
      (setq registro-diario--current-day next-str)
      (unless (gethash registro-diario--current-day registro-diario--worklogs-cache)
        (registro-diario--fetch-worklogs registro-diario--current-day))
      (registro-diario-render))))

(defun registro-diario-today ()
  "Vuelve al día de hoy."
  (interactive)
  (setq registro-diario--current-day (format-time-string "%Y-%m-%d"))
  (unless (gethash registro-diario--current-day registro-diario--worklogs-cache)
    (registro-diario--fetch-worklogs registro-diario--current-day))
  (registro-diario-render))

(defun registro-diario-inc-hours ()
  "Incrementa horas a registrar."
  (interactive)
  (setq registro-diario--selected-hours (min 8.0 (+ registro-diario--selected-hours 0.5)))
  (registro-diario-render))

(defun registro-diario-dec-hours ()
  "Reduce horas a registrar."
  (interactive)
  (setq registro-diario--selected-hours (max 0.5 (- registro-diario--selected-hours 0.5)))
  (registro-diario-render))

(defun registro-diario-set-activity ()
  "Selecciona la actividad o ceremonia."
  (interactive)
  (let ((act (completing-read "Actividad / Ceremonia: " '("Refinamiento" "Planning" "Retrospectiva" "Adicional" "Trabajo en tarea") nil t)))
    (setq registro-diario--selected-activity act)
    (registro-diario-render)))

(defun registro-diario-clear-story ()
  "Limpia la historia seleccionada para ver todas las tareas."
  (interactive)
  (setq registro-diario--selected-story nil)
  (registro-diario-render))

(defun registro-diario--action-on-story (key summary)
  "Acción al hacer clic en una historia: seleccionarla o crear tarea."
  (if (string= registro-diario--selected-story key)
      (when (yes-or-no-p (format "¿Crear y registrar tarea de %s para %s?" registro-diario--selected-activity key))
        (let* ((detail (read-string (format "Detalle de tarea para %s: " key) registro-diario--selected-activity))
               (issue-item (cl-find-if (lambda (it) (string= (plist-get it :key) key)) registro-diario--issues))
               (p-key (plist-get issue-item :project-key))
               (created (registro-diario--jira-request "/rest/api/3/issue" "POST"
                                                       `((fields . ((project . ((key . ,(or p-key (car (split-string key "-"))))))
                                                                    (summary . ,(format "%s: %s" registro-diario--selected-activity detail))
                                                                    (issuetype . ((name . "Tarea"))))))))
               (new-key (gethash "key" created)))
          (when new-key
            ;; Enlazar con historia
            (condition-case nil
                (registro-diario--jira-request "/rest/api/3/issueLink" "POST"
                                               `((type . ((name . "Historia/Hitos")))
                                                 (inwardIssue . ((key . ,key)))
                                                 (outwardIssue . ((key . ,new-key)))))
              (error nil))
            ;; Registrar worklog
            (let ((m (* (round registro-diario--selected-hours) 60)))
              (registro-diario--jira-request (format "/rest/api/2/issue/%s/worklog" new-key) "POST"
                                             `((timeSpent . ,(format "%dh" (floor registro-diario--selected-hours)))
                                               (comment . ,detail))))
            (message "¡Tarea %s creada y registrada con éxito!" new-key)
            (registro-diario-refresh))))
    (setq registro-diario--selected-story key)
    (registro-diario-render)))

(defun registro-diario--action-on-task (key summary)
  "Acción al hacer clic en una tarea: registrar horas directamente."
  (when (yes-or-no-p (format "¿Registrar %s en %s (%s)?"
                             (registro-diario--format-hours registro-diario--selected-hours) key summary))
    (let ((spent (format "%dh" (floor registro-diario--selected-hours))))
      (registro-diario--jira-request (format "/rest/api/2/issue/%s/worklog" key) "POST"
                                     `((timeSpent . ,spent)
                                       (comment . ,registro-diario--selected-activity)))
      (message "¡Registradas %s en %s!" spent key)
      (registro-diario-refresh))))

(defun registro-diario-enter-action ()
  "Ejecuta la acción del elemento bajo el cursor."
  (interactive)
  (let ((btn (button-at (point))))
    (if btn
        (button-activate btn)
      (let ((task (get-text-property (point) 'registro-task))
            (story (get-text-property (point) 'registro-story)))
        (cond
         (task (registro-diario--action-on-task (plist-get task :key) (plist-get task :summary)))
         (story (registro-diario--action-on-story (plist-get story :key) (plist-get story :summary))))))))

(defun registro-diario-print-pdf ()
  "Lanza la generación de PDF con capturas en segundo plano."
  (interactive)
  (let ((py-script (expand-file-name "~/monoliths-llm/registro-diario-1bit.py")))
    (start-process "jira-pdf-bg" nil "python3" py-script "--generate-pdf-bg" registro-diario--current-day)
    (message "Generación de PDF lanzada en segundo plano para %s." registro-diario--current-day)))

(defun registro-diario-open-jira ()
  "Abre la tarea bajo el cursor en el navegador web."
  (interactive)
  (let* ((task (get-text-property (point) 'registro-task))
         (story (get-text-property (point) 'registro-story))
         (k (or (when task (plist-get task :key))
                (when story (plist-get story :key))))
         (domain (directory-file-name (gethash "JIRA_DOMAIN" registro-diario--config))))
    (if k
        (browse-url (format "%s/browse/%s" domain k))
      (message "Coloca el cursor sobre una tarea o historia para abrir."))))

;;;###autoload
(defun registro-diario ()
  "Inicia la consola interactiva de registro de horas Jira en un buffer de Emacs."
  (interactive)
  (registro-diario--read-config)
  (registro-diario-refresh))

(provide 'registro-diario-emacs)
;;; registro-diario-emacs.el ends here
