#!/bin/dash

TAR_FILE="antigravity.tar.gz"
EXTRACT_DIR="antigravity-package"

# 2. Verificar que el tarball existe en el directorio actual
if [ ! -f "$TAR_FILE" ]; then
  echo "Error: No se encuentra '$TAR_FILE' en este directorio."
  exit 1
fi

echo ">> Extrayendo $TAR_FILE..."
# Extraemos el contenido. Esto creará la carpeta 'antigravity-package'
tar -xzvf "$TAR_FILE"

echo ">> Instalando archivos en el sistema..."
# 3. Copiamos los archivos a sus directorios correspondientes en el sistema
doas cp -v "$EXTRACT_DIR/usr/bin/antigravity" /usr/bin/
doas cp -rv "$EXTRACT_DIR/usr/share/antigravity" /usr/share/

# 4. Asegurarnos de que el binario tenga permisos de ejecución
doas mv /usr/bin/antigravity /usr/bin/antigravity.original
doas cp ~/monoliths-llm/antigravity-fix /usr/bin/antigravity
doas chmod 755 /usr/bin/antigravity

echo ">> Limpiando archivos temporales..."
# 5. Borramos la carpeta extraída para no dejar basura
rm -rf "$EXTRACT_DIR"

echo "¡Instalación de antigravity completada con éxito!"