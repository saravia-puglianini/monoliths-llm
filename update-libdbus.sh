#!/bin/dash

# 1. Buscar la ubicación de libdbus-1.so.3 en el sistema actual
LIB_PATH=""
for path in /usr/lib64 /usr/lib /lib64 /lib /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu; do
    if [ -f "$path/libdbus-1.so.3" ]; then
        LIB_PATH="$path"
        break
    fi
done

if [ -z "$LIB_PATH" ]; then
    echo "Error: No se encuentra libdbus-1.so.3 en el sistema."
    exit 1
fi

echo ">> Encontrado libdbus en: $LIB_PATH"

PACKAGE_DIR="$HOME/monoliths-llm/libdbus-package"

# 2. Limpiar directorio previo si existe
[ -d "$PACKAGE_DIR" ] && rm -rf "$PACKAGE_DIR"

# 3. Crear estructura del paquete
mkdir -p "$PACKAGE_DIR/usr/lib"

# 4. Copiar el archivo real resolviendo el enlace simbólico
REAL_FILE=$(readlink -f "$LIB_PATH/libdbus-1.so.3")
REAL_NAME=$(basename "$REAL_FILE")

echo ">> Copiando archivo real: $REAL_FILE"
cp -a "$REAL_FILE" "$PACKAGE_DIR/usr/lib/"

# 5. Crear el enlace simbólico dentro del paquete de forma relativa
cd "$PACKAGE_DIR/usr/lib"
ln -sf "$REAL_NAME" libdbus-1.so.3
ln -sf "$REAL_NAME" libdbus-1.so

# 6. Volver al directorio de monoliths-llm y empaquetar
cd "$HOME/monoliths-llm"
[ -f "libdbus.tar.gz" ] && mv "libdbus.tar.gz" /tmp/

echo ">> Empaquetando en libdbus.tar.gz..."
tar -czvf libdbus.tar.gz libdbus-package

# Limpiar carpeta temporal
rm -rf "$PACKAGE_DIR"

[ -f libdbus.tar.gz ] && echo 'libdbus.tar.gz actualizado!!!'
