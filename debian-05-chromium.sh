#!/bin/dash

# README
# Asegúrate de tener: deb-src http://deb.debian.org/debian trixie main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/chromium-build && cd $HOME/chromium-build && apt source chromium

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
true # sudo apt update
sudo apt build-dep chromium -y
sudo apt install -y devscripts quilt ccache -y

echo '=== 1.1 Configurando ccache (100GB) ==='
export CCACHE_DIR="$HOME/.ccache"
ccache -M 100G

echo '=== 2. Entrando al directorio del código fuente ==='
cd chromium-*/
sudo chown -R $USER:$USER .

echo '=== 2.1 Parcheando debian/rules para usar ccache con GN ==='
# Insertamos cc_wrapper="ccache" en las definiciones de GN en debian/rules
sed -i '/defines+=is_debug=false/a \         cc_wrapper="ccache" \\' debian/rules

echo '=== 3. Configurando flags de optimización ==='
export DEB_CFLAGS_APPEND="-O3"
export DEB_CXXFLAGS_APPEND="-O3"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +o3 'Recompilando con -O3'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i --force-confold ./*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Ya puedes ejecutar 'chromium' ==="
