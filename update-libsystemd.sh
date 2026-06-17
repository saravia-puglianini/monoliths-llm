#!/bin/dash

# 1. Buscar la ubicación de libsystemd.so.0 en el sistema actual
LIB_PATH=""
for path in /usr/lib64 /usr/lib /lib64 /lib /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu; do
    if [ -f "$path/libsystemd.so.0" ]; then
        LIB_PATH="$path"
        break
    fi
done

if [ -z "$LIB_PATH" ]; then
    echo "Error: No se encuentra libsystemd.so.0 en el sistema."
    exit 1
fi

echo ">> Encontrado libsystemd en: $LIB_PATH"

PACKAGE_DIR="$HOME/monoliths-llm/libsystemd-package"

# 2. Limpiar directorio previo si existe
[ -d "$PACKAGE_DIR" ] && rm -rf "$PACKAGE_DIR"

# 3. Crear estructura del paquete
mkdir -p "$PACKAGE_DIR/usr/lib"

# 4. Copiar el archivo real resolviendo el enlace simbólico
REAL_FILE=$(readlink -f "$LIB_PATH/libsystemd.so.0")
REAL_NAME=$(basename "$REAL_FILE")

echo ">> Copiando archivo real: $REAL_FILE"
cp -a "$REAL_FILE" "$PACKAGE_DIR/usr/lib/"

# 5. Crear los enlaces simbólicos dentro del paquete de forma relativa
cd "$PACKAGE_DIR/usr/lib"
ln -sf "$REAL_NAME" libsystemd.so.0
ln -sf "$REAL_NAME" libsystemd.so

# 6. Volver al directorio de monoliths-llm y empaquetar
cd "$HOME/monoliths-llm"
[ -f "libsystemd.tar.gz" ] && mv "libsystemd.tar.gz" /tmp/

echo ">> Empaquetando en libsystemd.tar.gz..."
tar -czvf libsystemd.tar.gz libsystemd-package

# Limpiar carpeta temporal
rm -rf "$PACKAGE_DIR"

[ -f libsystemd.tar.gz ] && echo 'libsystemd.tar.gz actualizado!!!'
