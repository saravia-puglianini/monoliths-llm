#!/bin/dash

# 1. Buscar la ubicación de libatk-bridge-2.0.so.0 en el sistema actual
LIB_PATH=""
for path in /usr/lib64 /usr/lib /lib64 /lib /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu; do
    if [ -f "$path/libatk-bridge-2.0.so.0" ]; then
        LIB_PATH="$path"
        break
    fi
done

if [ -z "$LIB_PATH" ]; then
    echo "Error: No se encuentra libatk-bridge-2.0.so.0 en el sistema."
    exit 1
fi

echo ">> Encontrado libatk-bridge en: $LIB_PATH"

PACKAGE_DIR="$HOME/monoliths-llm/libatk-bridge-package"

# 2. Limpiar directorio previo si existe
[ -d "$PACKAGE_DIR" ] && rm -rf "$PACKAGE_DIR"

# 3. Crear estructura del paquete
mkdir -p "$PACKAGE_DIR/usr/lib"

# 4. Copiar el archivo real resolviendo el enlace simbólico
REAL_FILE=$(readlink -f "$LIB_PATH/libatk-bridge-2.0.so.0")
REAL_NAME=$(basename "$REAL_FILE")

echo ">> Copiando archivo real: $REAL_FILE"
cp -a "$REAL_FILE" "$PACKAGE_DIR/usr/lib/"

# 5. Crear los enlaces simbólicos dentro del paquete de forma relativa
cd "$PACKAGE_DIR/usr/lib"
ln -sf "$REAL_NAME" libatk-bridge-2.0.so.0
ln -sf "$REAL_NAME" libatk-bridge-2.0.so

# 6. Volver al directorio de monoliths-llm y empaquetar
cd "$HOME/monoliths-llm"
[ -f "libatk-bridge.tar.gz" ] && mv "libatk-bridge.tar.gz" /tmp/

echo ">> Empaquetando en libatk-bridge.tar.gz..."
tar -czvf libatk-bridge.tar.gz libatk-bridge-package

# Limpiar carpeta temporal
rm -rf "$PACKAGE_DIR"

[ -f libatk-bridge.tar.gz ] && echo 'libatk-bridge.tar.gz actualizado!!!'
