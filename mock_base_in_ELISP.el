(require 'cl-lib)
(require 'json)

(cl-defstruct endpoint
  method
  path
  request
  response)

(defvar *endpoints* nil)

(defun trim-string (s)
  (replace-regexp-in-string "\\`[ \t\n\r]+\\|[ \t\n\r]+\\'" "" s))

(defun parse-data-http (filename)
  "Parsear data.http y guardar endpoints en *endpoints*."
  (with-temp-buffer
    (insert-file-contents filename)
    (let ((lines (split-string (buffer-string) "\n"))
          (current nil)
          endpoints)
      (dolist (line lines)
        (setq line (trim-string line))
        (cond
         ((string-prefix-p "###" line) nil)
         ((string-match-p "^GET " line)
          (when current (push current endpoints))
          (setq current (make-endpoint
                         :method "GET"
                         :path (string-trim (substring line 4)))))
         ((string-match-p "^POST " line)
          (when current (push current endpoints))
          (setq current (make-endpoint
                         :method "POST"
                         :path (string-trim (substring line 5)))))
         ((string-prefix-p "# Request:" line)
          (let ((buf ""))
            (while (and lines (not (string-prefix-p "###" (car lines))))
              (setq buf (concat buf (car lines)))
              (setq lines (cdr lines)))
            (setf (endpoint-request current) buf)))
         ((string-prefix-p "# Response:" line)
          (let ((buf ""))
            (while (and lines (not (string-prefix-p "###" (car lines))))
              (setq buf (concat buf (car lines)))
              (setq lines (cdr lines)))
            (setf (endpoint-response current) buf)))))
      (when current (push current endpoints))
      (setq *endpoints* (nreverse endpoints)))))

(defun parse-http-request (data)
  "Parsear request HTTP simple y devolver plist con :method :path :body."
  (let* ((lines (split-string data "\r\n"))
         (request-line (car lines))
         (body "")
         (method nil)
         (path nil))
    (when (string-match "\\([A-Z]+\\) \\([^ ]+\\)" request-line)
      (setq method (match-string 1 request-line))
      (setq path (match-string 2 request-line)))
    ;; Buscar separación entre headers y body
    (let ((idx (cl-position "" lines :test 'string=)))
      (when idx
        (setq body (mapconcat 'identity (nthcdr (1+ idx) lines) "\n"))))
    (list :method method :path path :body body)))

(defun http-server-filter (proc string)
  "Procesar request HTTP entrante en PROC."
  (with-current-buffer (process-buffer proc)
    ;; Acumular datos por conexión
    (let ((data (concat (or (process-get proc 'data) "") string)))
      (process-put proc 'data data)
      ;; Procesar solo si tenemos línea de request completa
      (when (string-match "\r?\n\r?\n" data)
        (let* ((req (parse-http-request data))
               (method (plist-get req :method))
               (path (plist-get req :path))
               (body (plist-get req :body))
               (found nil))
          (dolist (ep *endpoints*)
            (when (and (string= method (endpoint-method ep))
                       (string= path (endpoint-path ep))
                       (or (not (endpoint-request ep)) ; GET o POST sin validar body
                           (string= body (endpoint-request ep))))
              (setq found t)
              (process-send-string proc
                                   (format "HTTP/1.1 %s OK\r\nContent-Type: application/json\r\n\r\n%s"
                                           (if (string= method "POST") 201 200)
                                           (endpoint-response ep)))
              (process-send-eof proc)))
          (unless found
            (process-send-string proc
                                 "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n{\"error\":\"endpoint no encontrado\"}")
            (process-send-eof proc))
          (process-put proc 'data nil))))))

(defun start-http-mock-server (port)
  "Levantar servidor HTTP simple en PORT usando solo Emacs base."
  (interactive "nPuerto: ")
  (parse-data-http "$HOME/mock_base_in_C/data.http")
  (make-network-process
   :name "mock-http-server"
   :buffer "*mock-http-server*"
   :family 'ipv4
   :service port
   :server t
   :filter 'http-server-filter)
  (message "Servidor mock HTTP corriendo en puerto %d" port))
