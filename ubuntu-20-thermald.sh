#!/bin/dash

# README
# Asegúrate de tener: deb-src http://archive.ubuntu.com/ubuntu noble main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/thermald-build && cd $HOME/thermald-build && apt source thermald

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
true # sudo apt update
sudo apt build-dep thermald -y
sudo apt install -y devscripts quilt ccache -y

echo "=== 1.1 Configurando ccache ==="
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 50G

echo '=== 2. Preparando código fuente ==='
# Si no hay carpeta, extraemos el dsc
if [ ! -d thermald-*/ ]; then
    echo "Extrayendo código fuente desde el archivo .dsc..."
    dpkg-source -x thermald_*.dsc
fi

cd thermald-*/
sudo chown -R $USER:$USER .

echo '=== 3. Configurando flags de optimización y parches ==='
export DEB_CFLAGS_APPEND="-O3 -Wno-error"
export DEB_CXXFLAGS_APPEND="-O3 -Wno-error"
export DEB_LDFLAGS_APPEND=""

# 3.1 Parchear debian/rules para asegurar que --disable-werror se pase al configure
if grep -q "dh_auto_configure --" debian/rules; then
    sed -i 's/dh_auto_configure --/dh_auto_configure -- --disable-werror/' debian/rules
else
    printf "\noverride_dh_auto_configure:\n\tdh_auto_configure -- --disable-werror\n" >> debian/rules
fi

echo '=== 4. Modificando el changelog para proteger el paquete ==='
# Usamos un mensaje único para evitar conflictos con compilaciones previas
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +o3final 'Recompilando con -O3, ccache y --disable-werror'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i --force-confold ./*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Ya puedes reiniciar thermald ==="
