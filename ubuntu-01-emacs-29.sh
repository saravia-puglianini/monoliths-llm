#!/bin/dash

# README
# Este script descarga el código fuente de Emacs 29.4 desde GNU,
# instala las dependencias necesarias para compilación nativa con GCC 11
# y genera los paquetes .deb para su instalación.

set -e

echo '=== 1. Instalando dependencias necesarias (GCC 11 compatible) ==='
sudo apt update
sudo apt install -y software-properties-common devscripts checkinstall
sudo apt build-dep emacs -y
sudo apt install -y libjansson-dev libxml2-dev libgnutls28-dev \
    libgccjit-11-dev libsystemd-dev libjansson-dev libxml2-dev \
    libncurses-dev gnutls-dev libxpm-dev libjpeg-dev libtiff-dev \
    libgif-dev libpng-dev libx11-dev libgtk-3-dev libwebp-dev \
    libsqlite3-dev libtree-sitter-dev libwebkit2gtk-4.1-dev libwebkit2gtk-4.0-dev

export CC=gcc-11
export CXX=g++-11

echo '=== 2. Descargando código fuente de Emacs 29.4 ==='
EMACS_VER="29.4"
rm -rf emacs-$EMACS_VER*
wget https://ftp.gnu.org/gnu/emacs/emacs-$EMACS_VER.tar.gz
tar -xzf emacs-$EMACS_VER.tar.gz
cd emacs-$EMACS_VER

echo '=== 2.1 Aplicando parche de interfaz ==='
if [ -f ../0001-frame-defaults-no-gui-bars.patch ]; then
    echo "Aplicando parche ../0001-frame-defaults-no-gui-bars.patch..."
    patch -p1 < ../0001-frame-defaults-no-gui-bars.patch
else
    echo "No se encontró el parche ../0001-frame-defaults-no-gui-bars.patch, saltando."
fi

echo '=== 3. Configurando para compilación nativa y optimizaciones ==='
export CFLAGS="-O3 -march=native"
export LDFLAGS="-Wl,-O1"

./autogen.sh
./configure --with-native-compilation=yes \
            --with-json \
            --with-tree-sitter \
            --with-xwidgets \
            --with-x-toolkit=gtk3 \
            --with-mailutils \
            --with-compress-install

echo '=== 4. Compilando (usando todos los cores) ==='
make -j$(nproc)

echo '=== 5. Generando paquete .deb con checkinstall ==='
# Creamos el paquete .deb para que el orquestador lo gestione
sudo checkinstall -y \
    --pkgname=emacs29 \
    --pkgversion="$EMACS_VER" \
    --pkgrelease="local-o3" \
    --pkgsource="https://ftp.gnu.org/gnu/emacs/" \
    --maintainer="local@localhost" \
    --requires="libgccjit-11-dev,libtree-sitter0" \
    --provides="emacs,emacs-gtk" \
    --nodoc

echo '=== 6. Moviendo paquete al directorio de trabajo ==='
mv emacs29_*.deb ../

echo "=== ¡Proceso de compilación de Emacs $EMACS_VER completado! ==="
