#!/bin/dash

PACKAGE_DIR="$HOME/monoliths-llm/antigravity-portable-package"

# 1. Limpiar directorio previo si existe
[ -d "$PACKAGE_DIR" ] && rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/usr/share/antigravity/lib"

echo ">> Localizando y copiando dependencias del sistema..."

# Función para buscar y copiar una biblioteca con sus enlaces simbólicos correspondientes
copy_lib() {
    lib_name="$1"
    found_path=""
    for path in /usr/lib64 /usr/lib /lib64 /lib /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu; do
        if [ -f "$path/$lib_name" ]; then
            found_path="$path"
            break
        fi
    done

    if [ -z "$found_path" ]; then
        # Intentar buscar usando find si no se encontró en las rutas estándar
        found_file=$(find /lib* /usr/lib* -name "$lib_name" -print -quit 2>/dev/null)
        if [ -n "$found_file" ]; then
            found_path=$(dirname "$found_file")
        fi
    fi

    if [ -n "$found_path" ]; then
        REAL_FILE=$(readlink -f "$found_path/$lib_name")
        REAL_NAME=$(basename "$REAL_FILE")
        echo "   [+] Encontrada $lib_name en $found_path (Real: $REAL_NAME)"
        cp -a "$REAL_FILE" "$PACKAGE_DIR/usr/share/antigravity/lib/"
        cd "$PACKAGE_DIR/usr/share/antigravity/lib"
        ln -sf "$REAL_NAME" "$lib_name"
        # Crear enlace general sin versión menor si aplica (ej. libdbus-1.so)
        base_name=$(echo "$lib_name" | sed 's/\.so\.[0-9]\+$/\.so/')
        if [ "$base_name" != "$lib_name" ]; then
            ln -sf "$REAL_NAME" "$base_name"
        fi
        cd - >/dev/null
    else
        echo "   [-] ADVERTENCIA: No se encontró $lib_name"
    fi
}

# Copiar las bibliotecas del sistema requeridas
copy_lib "libdbus-1.so.3"
copy_lib "libatk-bridge-2.0.so.0"
copy_lib "libatspi.so.0"
copy_lib "libsystemd.so.0"

# Copiar las bibliotecas de glib y dependencias cascading requeridas
copy_lib "libglib-2.0.so.0"
copy_lib "libgobject-2.0.so.0"
copy_lib "libgio-2.0.so.0"
copy_lib "libgmodule-2.0.so.0"
copy_lib "libatk-1.0.so.0"
copy_lib "libffi.so.8"
copy_lib "libpcre2-8.so.0"
copy_lib "libz.so.1"
copy_lib "libmount.so.1"
copy_lib "libblkid.so.1"

# Copiar las bibliotecas de glibc moderna para que sirvan de capa de aislamiento portable
copy_lib "ld-linux-x86-64.so.2"
copy_lib "libc.so.6"
copy_lib "libm.so.6"
copy_lib "libgcc_s.so.1"
copy_lib "libresolv.so.2"
copy_lib "librt.so.1"
copy_lib "libdl.so.2"
copy_lib "libpthread.so.0"

# 2. Copiar y parchear el binario ELF original de Antigravity
echo ">> Copiando y parcheando el binario ELF original de Antigravity..."
mkdir -p "$PACKAGE_DIR/usr/share/antigravity"
cp -a /usr/share/antigravity/antigravity "$PACKAGE_DIR/usr/share/antigravity/antigravity"

# Cambiar el intérprete ELF y el RPATH del binario copiado
patchelf --set-interpreter /lib64/ld-antigravity.so \
         --set-rpath /usr/share/antigravity/lib \
         "$PACKAGE_DIR/usr/share/antigravity/antigravity"

echo "   [+] Binario ELF parcheado con éxito."

# 3. Volver al directorio de monoliths-llm y empaquetar
cd "$HOME/monoliths-llm"
[ -f "antigravity-portable-libs.tar.gz" ] && mv "antigravity-portable-libs.tar.gz" /tmp/

echo ">> Empaquetando en antigravity-portable-libs.tar.gz..."
tar -czvf antigravity-portable-libs.tar.gz antigravity-portable-package

# Limpiar carpeta temporal
rm -rf "$PACKAGE_DIR"

[ -f antigravity-portable-libs.tar.gz ] && echo 'antigravity-portable-libs.tar.gz actualizado con éxito!!!'
