#!/bin/dash

# README
# Compilación optimizada para thermald en Debian

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
true # sudo apt update
sudo apt build-dep thermald -y
sudo apt install -y devscripts quilt ccache -y

echo "=== 1.1 Configurando ccache ==="
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 50G

echo '=== 2. Entrando al directorio del código fuente ==='
# Usamos cd */ para entrar al directorio del fuente sin importar el nombre exacto
cd */
sudo chown -R $USER:$USER .

echo '=== 3. Configurando flags de optimización ==='
export DEB_CFLAGS_APPEND="-O3 -Wno-error"
export DEB_CXXFLAGS_APPEND="-O3 -Wno-error"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +o3 'Recompilando con -O3'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i --force-confold ./*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Ya puedes ejecutar 'thermald' ==="
