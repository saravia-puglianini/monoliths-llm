#!/usr/bin/env bash

# Script to switch to Linux kernel 5.10 (modo optime)
TARGET_VERSION="5.10"
MODE_DIR="$HOME/Mode"

# Get current kernel version (strip possible extra suffixes)
CURRENT_VERSION=$(uname -r | cut -d- -f1)

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
  echo "Ya estamos en modo optime (kernel $TARGET_VERSION)."
  exit 0
fi

if [[ ! -d "$MODE_DIR" ]]; then
  echo "Error: directorio $MODE_DIR no existe. No se puede instalar kernel $TARGET_VERSION."
  exit 1
fi

echo "Instalando kernel $TARGET_VERSION desde $MODE_DIR..."
# ---- Insert real installation commands below ----
# Install kernel, API headers, and headers for the target version
# Find all packages that contain the target version in their name
PKG_FILES=$(ls "$MODE_DIR"/*${TARGET_VERSION}*.pkg.tar.lz 2>/dev/null)

if [[ -n "$PKG_FILES" ]]; then
  echo "Instalando paquetes para versión $TARGET_VERSION: $PKG_FILES"
  doas pacman -U $PKG_FILES --noconfirm
else
  echo "No se encontraron paquetes para la versión $TARGET_VERSION en $MODE_DIR."
  exit 1
fi
# ------------------------------------------------

# Validation: verify that the installed kernel package version contains the target version
INSTALLED_VERSION=$(pacman -Q linux-libre-lts | awk '{print $2}')
if [[ "$INSTALLED_VERSION" == *${TARGET_VERSION}* ]]; then
  echo "Instalación completada. Versión instalada: $INSTALLED_VERSION"
else
  echo "Fallo la instalación. La versión del kernel instalada ($INSTALLED_VERSION) no coincide con $TARGET_VERSION."
  exit 1
fi

read -p "Precione Return para reiniciar..." _
# Uncomment the next line to actually reboot
doas reboot
