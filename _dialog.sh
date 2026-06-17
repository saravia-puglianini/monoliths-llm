#!/bin/sh

# Asegurar que dialog existe
command -v dialog >/dev/null 2>&1 || {
    echo 'dialog no está instalado.'; exit 1;
}

# Pregunta 1
dialog --title 'rms-Hacking' \
       --yesno '¿Continuar con rms-Hacking?' 8 50

resp=$?
clear

if [ "$resp" -eq 0 ]; then
    echo 'Iniciando Emacs...'
    exec emacs
else
    # Pregunta 2
    dialog --title 'Reinicio gráfico' \
	   --yesno '¿Reiniciar con gráficos?' 8 50

    resp2=$?
    clear

    if [ "$resp2" -eq 0 ]; then
	doas cp /etc/default/grub.normal /etc/default/grub \
	    && doas grub-mkconfig -o /boot/grub/grub.cfg \
	    && doas reboot
    else

	# Pregunta 3
	dialog --title 'Reinicio tty modeset hack' \
	       --yesno '¿Reiniciar con tty modeset hack?' 8 50

	resp3=$?
	clear

	if [ "$resp3" -eq 0 ]; then
	    ( [ -f /etc/default/grub.normal ] || doas cp /etc/default/grub /etc/default/grub.normal ) && \
		cat /etc/default/grub | grep -q '800x600' && \
		( doas cp /etc/default/grub.normal /etc/default/grub ) || \
		    ( echo 'GRUB_CMDLINE_LINUX_DEFAULT='nomodeset'' | doas tee -a /etc/default/grub && \
			  echo 'GRUB_GFXMODE=800x600' | doas tee -a /etc/default/grub && \
			  echo 'GRUB_GFXPAYLOAD_LINUX=keep' | doas tee -a /etc/default/grub ) && \
			( doas grub-mkconfig -o /boot/grub/grub.cfg && doas reboot )
	else
	    echo 'Acción cancelada.'
	fi
    fi
fi
