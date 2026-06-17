#!/bin/dash

# List of already optimized packages (scripts 01-17)
OPTIMIZED="emacs bash blueman bluez chromium-browser coreutils dash dbus grep openbox pulseaudio procps pavucontrol wireplumber xbindkeys xinit xorg-server network-manager conky-all gnome-shell thermald acpid avahi-daemon"

# Proponer paquetes comunes que suelen estar encendidos
for proc in conky gnome-shell thermald acpid avahi-daemon; do
    pkg=$(dpkg-query -S $(which $proc 2>/dev/null) 2>/dev/null | cut -d: -f1 | head -n1)
    [ -z "$pkg" ] && continue
    
    # Check if optimized
    found=0
    for opt in $OPTIMIZED; do
        if [ "$pkg" = "$opt" ]; then found=1; break; fi
    done
    [ "$found" -eq 1 ] && continue

    echo "Generando script para $pkg..."
    
    # Generate the script name
    last_num=$(ls ubuntu-*.sh | grep -o '[0-9]\+' | sort -n | tail -n1)
    next_num=$(expr $last_num + 1)
    filename="ubuntu-$(printf "%02d" $next_num)-$pkg.sh"
    
    cat <<EOF > "$filename"
#!/bin/dash

# README
# Asegúrate de tener: deb-src http://archive.ubuntu.com/ubuntu noble main en sources.list
# Y haber ejecutado previamente:
# mkdir \$HOME/$pkg-build && cd \$HOME/$pkg-build && apt source $pkg

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
true # sudo apt update
sudo apt build-dep $pkg -y
sudo apt install -y devscripts quilt ccache -y

echo '=== 1.1 Configurando ccache ==='
export PATH="/usr/lib/ccache:\$PATH"
export CCACHE_DIR="\$HOME/.ccache"
ccache -M 50G

echo '=== 2. Entrando al directorio del código fuente ==='
cd */
sudo chown -R \$USER:\$USER .

echo '=== 3. Configurando flags de optimización ==='
export DEB_CFLAGS_APPEND="-O3 -Wno-error"
export DEB_CXXFLAGS_APPEND="-O3 -Wno-error"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +o3 'Recompilando con -O3 y ccache'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i --force-confold ./*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Ya puedes reiniciar $pkg ==="
EOF
    chmod +x "$filename"
    echo "Creado: $filename"
    
    # Update optimized list for next iteration
    OPTIMIZED="$OPTIMIZED $pkg"
done
