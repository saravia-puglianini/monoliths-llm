#!/bin/dash

# README
# Asegúrate de tener: deb-src http://archive.ubuntu.com/ubuntu noble main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/chromium-build && cd $HOME/chromium-build && apt source chromium

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
sudo apt update || true
sudo apt install -y wget lsb-release software-properties-common gnupg curl
# Instalar LLVM 20
wget -qO- https://apt.llvm.org/llvm.sh | sudo bash -s -- 20
# Restaurar nodejs system-wide y dependencias (eliminando Nodesource)
sudo rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources
sudo apt update || true
sudo apt install -y --allow-downgrades nodejs="12.22.9~dfsg-1ubuntu3.6"
sudo apt build-dep chromium -y
sudo apt install -y devscripts quilt ccache

echo '=== 1.1 Descargando Node.js moderno (20.x) como binario independiente ==='
# Chromium requiere node 14+ pero Ubuntu 22.04 tiene node 12.
# Descargamos un Node.js moderno sin romper los paquetes deb de rollup.
NODE_VERSION="v20.18.0"
cd /tmp
wget -q -nc https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz
tar -xf node-$NODE_VERSION-linux-x64.tar.xz
export STANDALONE_NODE="/tmp/node-$NODE_VERSION-linux-x64/bin/node"
cd -


echo '=== 1.1 Configurando ccache (100GB) ==='
export CCACHE_DIR="$HOME/.ccache"
ccache -M 100G

echo '=== 1.2 Actualizando binario GN desde código base (requerido para Chromium 140+) ==='
sudo apt install -y git python3 ninja-build
# Si gn version es '1000' u '0.0' o similar, o no existe, instalamos uno nuevo:
if ! gn --version 2>/dev/null | grep -q "^[1-9][0-9]*$"; then
    echo "Construyendo GN moderno..."
    CUR_DIR=$(pwd)
    cd /tmp
    rm -rf gn
    git clone https://gn.googlesource.com/gn
    cd gn
    export CC=gcc CXX=g++
    python3 build/gen.py
    sed -i 's/-Werror//g' out/build.ninja
    ninja -C out
    sudo cp out/gn /usr/bin/gn
    cd "$CUR_DIR"
fi

echo '=== 2. Entrando al directorio del código fuente ==='
cd chromium-*/
sudo chown -R $USER:$USER .

echo '=== 2.1 Parcheando debian/rules para usar ccache con GN ==='
# Limpieza previa para evitar duplicados en re-ejecución
sed -i '/cc_wrapper=\\"ccache\\"/d' debian/rules
# Insertamos cc_wrapper="ccache" en las definiciones de GN en debian/rules
sed -i '/defines+=is_debug=false/a \         cc_wrapper=\\"ccache\\" \\' debian/rules

echo '=== 2.2 Corrigiendo dependencias de harfbuzz-subset (usando versión bundled) ==='
# Ubuntu 22.04 no tiene harfbuzz-subset.pc, forzamos uso de la versión interna de Chromium
sed -i 's/use_system_harfbuzz=true/use_system_harfbuzz=false/' debian/rules


echo '=== 2.3 Usar Node.js moderno independiente para compilación ==='
sed -i 's|cp /usr/bin/node|cp /tmp/node-v20.18.0-linux-x64/bin/node|g' debian/rules

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
