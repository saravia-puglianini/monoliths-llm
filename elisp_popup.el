(defun popup-current-buffer ()
  "Abrir el buffer actual en una ventana emergente."
  (interactive)
  (display-buffer
   (current-buffer)
   '((display-buffer-pop-up-window)
     (inhibit-same-window . t))))
