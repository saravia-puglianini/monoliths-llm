#!/bin/dash

# 1. Verificar si Google Chrome Stable está instalado en la máquina actual
if [ ! -d "/opt/google/chrome" ]; then
    echo "Error: No se encuentra /opt/google/chrome en el sistema. Google Chrome Stable no está instalado."
    exit 1
fi

PACKAGE_DIR="$HOME/monoliths-llm/google-chrome-stable-package"

# 2. Limpiar directorio previo si existe
[ -d "$PACKAGE_DIR" ] && doas rm -rf "$PACKAGE_DIR"

# 3. Crear estructura del paquete
mkdir -p "$PACKAGE_DIR/opt/google"
mkdir -p "$PACKAGE_DIR/usr/share/applications"

# 4. Copiar archivos correspondientes conservando permisos, enlaces simbólicos y propiedades
echo ">> Copiando /opt/google/chrome..."
doas cp -a /opt/google/chrome "$PACKAGE_DIR/opt/google/"

# Copiar archivo .desktop si existe
if [ -f "/usr/share/applications/google-chrome.desktop" ]; then
    echo ">> Copiando google-chrome.desktop..."
    doas cp -a /usr/share/applications/google-chrome.desktop "$PACKAGE_DIR/usr/share/applications/"
fi

# Copiar los iconos asociados de Google Chrome si existen
ICON_DIR="$PACKAGE_DIR/usr/share/icons/hicolor"
for size in 16 22 24 32 48 64 128 256; do
    SYS_ICON="/usr/share/icons/hicolor/${size}x${size}/apps/google-chrome.png"
    if [ -f "$SYS_ICON" ]; then
        mkdir -p "$ICON_DIR/${size}x${size}/apps"
        doas cp -a "$SYS_ICON" "$ICON_DIR/${size}x${size}/apps/"
    fi
done

# 5. Volver al directorio de monoliths-llm
cd "$HOME/monoliths-llm"

# Si ya existe un tarball previo, lo movemos a /tmp/
[ -f "$HOME/monoliths-llm/google-chrome-stable.tar.gz" ] && mv "$HOME/monoliths-llm/google-chrome-stable.tar.gz" /tmp/

# Cambiar propiedad al usuario actual temporalmente para poder crear el tarball sin doas
doas chown -R "$(id -u):$(id -g)" "$PACKAGE_DIR"

echo ">> Empaquetando en google-chrome-stable.tar.gz..."
tar -czvf google-chrome-stable.tar.gz google-chrome-stable-package

# Limpiar carpeta temporal
rm -rf "$PACKAGE_DIR"

[ -f google-chrome-stable.tar.gz ] && echo 'google-chrome-stable.tar.gz actualizado!!!'
