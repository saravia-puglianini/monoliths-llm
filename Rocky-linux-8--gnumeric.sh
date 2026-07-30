#!/bin/bash
set -e

echo ">>> 0. Configurando entorno de compilación..."

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH

# Compatibilidad GCC moderno + proyectos antiguos
export CFLAGS="-O2 -g -std=gnu11 -Wno-error=deprecated-declarations -Wno-error=unused-variable"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="-include stdint.h"

# builds viejos = sin paralelismo
export MAKEFLAGS="-j1"

echo ">>> 1. Instalando herramientas..."
sudo dnf install -y epel-release dnf-plugins-core wget
sudo dnf groupinstall -y "Development Tools"

echo ">>> 2. Dependencias..."
sudo dnf install -y \
    bison autoconf automake libtool \
    glib2-devel gtk3-devel libxml2-devel pango-devel \
    yelp-tools python3-devel python3-gobject \
    gobject-introspection-devel gtk-doc \
    libxslt-devel librsvg2-devel intltool gperf \
    perl-IO-Compress glibc-headers glibc-devel

echo ">>> 3. Workspace..."
mkdir -p ~/gnumeric_build
cd ~/gnumeric_build

echo ">>> 4. Descargando fuentes..."
wget -nc https://download.gnome.org/sources/libgsf/1.14/libgsf-1.14.45.tar.xz
wget -nc https://download.gnome.org/sources/goffice/0.10/goffice-0.10.57.tar.xz
wget -nc https://download.gnome.org/sources/gnumeric/1.12/gnumeric-1.12.57.tar.xz

echo ">>> 5. Extrayendo..."
tar -xf libgsf-1.14.45.tar.xz
tar -xf goffice-0.10.57.tar.xz
tar -xf gnumeric-1.12.57.tar.xz

echo ">>> 6. libgsf..."
cd libgsf-1.14.45
./configure
make -j1
sudo make install
sudo ldconfig

echo ">>> 7. goffice..."
cd ../goffice-0.10.57

# fix menor conocido
sed -i '/go_register_ui_files/d' goffice/goffice.c || true

./configure CFLAGS="$CFLAGS"
make -j1
sudo make install
sudo ldconfig

echo ">>> 8. Gnumeric (FIX HTML DUPLICATE CASE)..."
cd ../gnumeric-1.12.57

# -----------------------------
# FIX 1: Pango API rename (opcional)
# -----------------------------
find . -name "html.c" -exec sed -i \
    -e 's/PANGO_UNDERLINE_SINGLE_LINE/PANGO_UNDERLINE_SINGLE/g' \
    -e 's/PANGO_UNDERLINE_DOUBLE_LINE/PANGO_UNDERLINE_DOUBLE/g' \
    -e 's/PANGO_UNDERLINE_ERROR_LINE/PANGO_UNDERLINE_ERROR/g' {} \;

# -----------------------------
# FIX 2: eliminar BLOQUE DUPLICADO de case en switch
# -----------------------------
for file in $(find . -name "html.c"); do
    awk '
    BEGIN {seen_single=0; seen_double=0; seen_error=0; infunc=0}
    /underline_span_pango/ {infunc=1; print; next}
    infunc && /case PANGO_UNDERLINE_SINGLE:/ {
        if (seen_single) next; seen_single=1
    }
    infunc && /case PANGO_UNDERLINE_DOUBLE:/ {
        if (seen_double) next; seen_double=1
    }
    infunc && /case PANGO_UNDERLINE_ERROR:/ {
        if (seen_error) next; seen_error=1
    }
    {print}
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done

# -----------------------------
# FIX 3: evitar romper build con warnings
# -----------------------------
export CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration"

# Deshabilitar el plugin HTML, que sigue problemático
./configure CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS" --disable-html
make -j1
sudo make install
sudo ldconfig

echo ">>> ✔ Instalación completada. Ejecuta: gnumeric"