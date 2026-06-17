(defun my-erc-setup-timestamps ()
  "Configura timestamps con microsegundos en ERC."
  (erc-timestamp-mode t)
  (setq erc-timestamp-format "%H:%M:%S.%6N "))

(add-hook 'erc-mode-hook #'my-erc-setup-timestamps)
