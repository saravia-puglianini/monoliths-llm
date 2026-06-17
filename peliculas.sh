#!/bin/dash

set -e

doas dash $HOME/monoliths-hm/optime.clean-all-users.sh hdmi

# Eliminar locks de X si existen
for display in 11; do
    lockfile="/tmp/.X${display}-lock"
    [ -e "$lockfile" ] && doas rm "$lockfile"
done

# Iniciar Xephyr en displays seleccionados
for display in 11; do
    if echo -n $display | grep '11'; then
	Xephyr -screen 832x604 :$display &
    else
	Xephyr :$display &
    fi
done

# Permitir acceso a los usuarios locales
for user in hdmi; do
    xhost +SI:localuser:$user
done

sleep 0.5  # espera a que Xephyr arranque

# Arrancar sshd si no está activo
if ! pgrep -x 'sshd' >/dev/null; then
    doas service sshd start
fi

# Iniciar Lumina para usuarios remotos usando ssh
# el siguiente paso requiere configuraciones en /etc/sshd_config
for user_display in 'hdmi:11'; do
    IFS=':' read -r user display <<EOF
$user_display
EOF
    ssh -o StrictHostKeyChecking=no $user@localhost \
        "DISPLAY=:$display start-lumina-desktop" &
done

echo 'Lumina sessions started on Xephyr displays.'
