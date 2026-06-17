#!/bin/dash

TAR_FILE="google-chrome-stable.tar.gz"
EXTRACT_DIR="google-chrome-stable-package"

# 1. Verificar que el tarball existe en el directorio actual
if [ ! -f "$TAR_FILE" ]; then
  echo "Error: No se encuentra '$TAR_FILE' en este directorio."
  exit 1
fi

echo ">> Extrayendo $TAR_FILE..."
# Extraemos el contenido. Esto creará la carpeta 'google-chrome-stable-package'
tar -xzvf "$TAR_FILE"

echo ">> Instalando archivos en el sistema..."
# 2. Copiamos los archivos a sus directorios correspondientes en el sistema
if [ -d "$EXTRACT_DIR/opt/google/chrome" ]; then
  doas mkdir -p /opt/google
  doas cp -a "$EXTRACT_DIR/opt/google/chrome" /opt/google/
fi

if [ -f "$EXTRACT_DIR/usr/share/applications/google-chrome.desktop" ]; then
  doas cp -a "$EXTRACT_DIR/usr/share/applications/google-chrome.desktop" /usr/share/applications/
fi

if [ -d "$EXTRACT_DIR/usr/share/icons" ]; then
  doas cp -a "$EXTRACT_DIR/usr/share/icons" /usr/share/
fi

# 3. Crear el enlace simbólico en /usr/bin/google-chrome-stable
echo ">> Creando enlace simbólico para google-chrome-stable..."
doas ln -sf /opt/google/chrome/google-chrome /usr/bin/google-chrome-stable

# 4. Asegurarnos de que el sandbox de Chrome tenga permisos correctos (setuid root)
if [ -f "/opt/google/chrome/chrome-sandbox" ]; then
  echo ">> Configurando permisos del sandbox de Chrome (setuid root)..."
  doas chown root:root /opt/google/chrome/chrome-sandbox
  doas chmod 4755 /opt/google/chrome/chrome-sandbox
fi

echo ">> Limpiando archivos temporales..."
# 5. Borramos la carpeta extraída para no dejar basura
rm -rf "$EXTRACT_DIR"

echo "¡Instalación de google-chrome-stable completada con éxito!"
