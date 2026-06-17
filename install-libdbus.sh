#!/bin/dash

TAR_FILE="libdbus.tar.gz"
EXTRACT_DIR="libdbus-package"

# 1. Verificar que el tarball existe en el directorio actual
if [ ! -f "$TAR_FILE" ]; then
  echo "Error: No se encuentra '$TAR_FILE' en este directorio."
  exit 1
fi

echo ">> Extrayendo $TAR_FILE..."
tar -xzvf "$TAR_FILE"

# 2. Identificar el archivo real y sus symlinks extraídos
REAL_FILE=$(find "$EXTRACT_DIR" -type f -name "libdbus-1.so.*")
if [ -z "$REAL_FILE" ]; then
  echo "Error: No se encontró el archivo libdbus real en el paquete."
  rm -rf "$EXTRACT_DIR"
  exit 1
fi
REAL_NAME=$(basename "$REAL_FILE")

echo ">> Instalando archivos en el sistema..."

# 3. Determinar el directorio de destino principal en el sistema
# En la mayoría de distros, /usr/lib es seguro y estándar.
# Si existe /usr/lib64, también instalamos o enlazamos allí.
TARGET_DIR="/usr/lib"
if [ -d "/usr/lib64" ]; then
  TARGET_DIR="/usr/lib64"
fi

echo ">> Copiando $REAL_NAME a $TARGET_DIR..."
doas cp -a "$REAL_FILE" "$TARGET_DIR/"

echo ">> Creando enlaces simbólicos en $TARGET_DIR..."
doas ln -sf "$REAL_NAME" "$TARGET_DIR/libdbus-1.so.3"
doas ln -sf "$REAL_NAME" "$TARGET_DIR/libdbus-1.so"

# 4. Si el destino era /usr/lib64 pero también existe /usr/lib, o viceversa, creamos enlaces cruzados para máxima compatibilidad
if [ "$TARGET_DIR" = "/usr/lib64" ] && [ -d "/usr/lib" ]; then
  echo ">> Creando enlaces de compatibilidad en /usr/lib..."
  doas ln -sf "$TARGET_DIR/$REAL_NAME" "/usr/lib/libdbus-1.so.3"
  doas ln -sf "$TARGET_DIR/$REAL_NAME" "/usr/lib/libdbus-1.so"
fi

if [ "$TARGET_DIR" = "/usr/lib" ] && [ -d "/usr/lib64" ]; then
  echo ">> Creando enlaces de compatibilidad en /usr/lib64..."
  doas ln -sf "$TARGET_DIR/$REAL_NAME" "/usr/lib64/libdbus-1.so.3"
  doas ln -sf "$TARGET_DIR/$REAL_NAME" "/usr/lib64/libdbus-1.so"
fi

# 5. Ejecutar ldconfig para actualizar el caché del enlazador dinámico
echo ">> Actualizando caché del enlazador dinámico (ldconfig)..."
if command -v ldconfig >/dev/null 2>&1; then
  doas ldconfig
elif [ -f "/sbin/ldconfig" ]; then
  doas /sbin/ldconfig
fi

echo ">> Limpiando archivos temporales..."
rm -rf "$EXTRACT_DIR"

echo "¡Instalación de libdbus completada con éxito!"
