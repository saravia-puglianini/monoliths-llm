#!/bin/bash
set -e

echo ">>> 0. Configurando entorno de compilación..."
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
export CFLAGS="-O2 -g -std=gnu11 -Wno-error=deprecated-declarations"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="-include stdint.h"
export MAKEFLAGS="-j$(nproc)"

echo ">>> 1. Instalando herramientas..."
sudo dnf install -y epel-release dnf-plugins-core wget git
sudo dnf groupinstall -y "Development Tools"

echo ">>> 2. Instalando dependencias..."
sudo dnf install -y \
    bison autoconf automake libtool \
    glib2-devel gtk3-devel libxml2-devel pango-devel \
    yelp-tools python3-devel python3-gobject \
    gobject-introspection-devel gtk-doc \
    libxslt-devel librsvg2-devel intltool gperf \
    perl-IO-Compress glibc-headers glibc-devel \
    libgsf-devel m4 autoconf-archive gettext

echo ">>> 3. Preparando workspace..."
mkdir -p ~/abiword_build
cd ~/abiword_build

echo ">>> 4. Descargando y compilando libgsf..."
wget -nc https://download.gnome.org/sources/libgsf/1.14/libgsf-1.14.45.tar.xz
tar -xf libgsf-1.14.45.tar.xz
cd libgsf-1.14.45
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

echo ">>> 5. Descargando AbiWord tarball oficial (3.0.4)..."
cd ~/abiword_build
wget -nc "https://github.com/AbiWord/abiword/archive/refs/tags/release-3.0.4.tar.gz"
tar -xf release-3.0.4.tar.gz
cd abiword-release-3.0.4

echo ">>> 6. Configurando AbiWord..."
./configure --prefix=/usr/local \
            CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=format-truncation" \
            CPPFLAGS="$CPPFLAGS" \
            --disable-debug \
            --disable-dependency-tracking

echo ">>> 7. Compilando AbiWord..."
make -j$(nproc)
sudo make install
sudo ldconfig

echo ">>> ✔ Instalación completada. Ejecuta: abiword"