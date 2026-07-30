#!/bin/sh

TITLE=$(cat /etc/default/grub | grep -q 'GRUB_CMDLINE_LINUX_DEFAULT='nomodeset'' && echo -n 'TTY-nomodeset-big-characters' || echo -n 'TTY-normal-characters')

RESTARTOPT=$(cat /etc/default/grub | grep -q 'GRUB_CMDLINE_LINUX_DEFAULT='nomodeset'' && echo -n 'con compatibilidad X (TTY-normal characters)' || echo -n 'en TTY-nomodeset-big-characters')


command -v dialog >/dev/null 2>&1 || {
    echo 'dialog no esta instalado.'
    exit 1
}

OPCION=$(dialog --title "$TITLE" \
		--menu 'Elige una accion:' 15 60 6 \
		1 "Iniciar Emacs $TITLE" \
		2 "Reiniciar $RESTARTOPT" \
		3 'Iniciar X' \
		4 'Sincronizar proyectos' \
		3>&1 1>&2 2>&3)

resp=$?
clear

[ "$resp" -ne 0 ] && {
    echo 'Accion cancelada.'
    exit 0
}

case "$OPCION" in
    1)
        echo 'Iniciando Emacs...'
        exec emacs
        ;;
    2)
	if cat /etc/default/grub | grep -q 'GRUB_CMDLINE_LINUX_DEFAULT='nomodeset''; then
            doas cp /etc/default/grub.normal /etc/default/grub \
		&& doas grub-mkconfig -o /boot/grub/grub.cfg \
		&& doas reboot
	else
            ( [ -f /etc/default/grub.normal ] || \
		  doas cp /etc/default/grub /etc/default/grub.normal ) && \
		grep -q '800x600' /etc/default/grub || \
		    {
			echo 'GRUB_CMDLINE_LINUX_DEFAULT='nomodeset'' | doas tee -a /etc/default/grub
			echo 'GRUB_GFXMODE=800x600' | doas tee -a /etc/default/grub
			echo 'GRUB_GFXPAYLOAD_LINUX=keep' | doas tee -a /etc/default/grub
		    } && \
			doas grub-mkconfig -o /boot/grub/grub.cfg \
			&& doas reboot
	fi	    
        ;;
    3)
	echo 'Iniciando X'
        startx
	;;
    4)
	echo 'Trae todo, envia todo'
        echo 'En construccion...'
	;;
esac
