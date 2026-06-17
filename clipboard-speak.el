(defun pliteratura-play-clipboard ()
  "Ejecuta pliteratura con el texto del portapapeles y reproduce el audio, sin mostrar buffers."
  (interactive)
  (let* ((text (current-kill 0 t))
         (escaped-text (replace-regexp-in-string "%" "%%" text))
         (cmd (format "$HOME/pliteratura/dist/pliteratura 'de' '/tmp/last_message.wav' \"%s!\" && mpv /tmp/last_message.wav"
                      escaped-text)))
    (start-process "pliteratura-play" nil "sh" "-c" cmd)))

(global-set-key (kbd "C-x x x") #'pliteratura-play-clipboard)
