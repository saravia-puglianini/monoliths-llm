#!/bin/dash

# README
# Asegúrate de tener: deb-src http://archive.ubuntu.com/ubuntu noble main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/chromium-build && cd $HOME/chromium-build && apt source chromium

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
sudo apt update || true
sudo apt install -y wget lsb-release software-properties-common gnupg curl
# Instalación de LLVM 20 y GCC 12 (requerido para que clang-20 encuentre libstdc++)
wget -qO- https://apt.llvm.org/llvm.sh | sudo bash -s -- 20
sudo apt update || true
sudo apt install -y g++-12 libstdc++-12-dev rustc-1.89
# Restaurar nodejs system-wide y dependencias (eliminando Nodesource)
sudo rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources
sudo apt update || true
sudo apt install -y --allow-downgrades nodejs="12.22.9~dfsg-1ubuntu3.6"
# Install snapcraft (classic confinement) for building snaps
sudo snap install snapcraft --classic || true

# Set aggressive -O3 native compilation flags
export CFLAGS="-O3 -march=native -pipe"
export CXXFLAGS="-O3 -march=native -pipe"
export LDFLAGS="-Wl,--as-needed"

# Ensure clang-20 via ccache is used for compilation
export CC="ccache clang-20"
export CXX="ccache clang++-20"

# Build the Chromium snap (destructive mode to use host toolchain)
# This will generate a .snap package in the current directory
snapcraft --destructive-mode || {
    echo "[!] Snapcraft build failed. Exiting."
    exit 1
}

# Install the generated snap (dangerous install)
SNAP_FILE=$(ls *.snap 2>/dev/null | head -n 1)
if [ -n "$SNAP_FILE" ]; then
    sudo snap install "./$SNAP_FILE" --dangerous
    echo "[✓] Chromium snap installed successfully."
    exit 0
else
    echo "[!] No snap file found after build."
    exit 1
fi