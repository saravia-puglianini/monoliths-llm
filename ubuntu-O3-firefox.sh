#!/bin/dash

# =============================================================================
# Script: ubuntu-O3-firefox.sh
# Description: Compila Firefox from source with aggressive -O3 optimizations on Ubuntu.
# =============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# ---------------------------------------------------------------------------
# 1. Install build dependencies (apt source + build-essential + ccache + rust)
# ---------------------------------------------------------------------------
sudo apt update -y
sudo apt install -y wget lsb-release software-properties-common gnupg curl
# Firefox build deps (as per Mozilla's documentation)
# Install the meta-package that pulls most required deps
sudo apt build-dep -y firefox || true
# Ensure we have a recent clang (for better optimizations) and ccache
# Install modern Node.js (20.x) as standalone binary
NODE_VERSION="v20.18.0"
cd /tmp
wget -q -nc https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz
tar -xf node-$NODE_VERSION-linux-x64.tar.xz
export STANDALONE_NODE="/tmp/node-$NODE_VERSION-linux-x64/bin/node"
export PATH="/tmp/node-$NODE_VERSION-linux-x64/bin:$PATH"
cd -

# Ensure clang-20 is used via ccache
export CC="ccache clang-20"
export CXX="ccache clang++-20"


# ---------------------------------------------------------------------------
# 2. Configure ccache (large enough for a full Firefox build)
# ---------------------------------------------------------------------------
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 100G

# ---------------------------------------------------------------------------
# 3. Obtain Firefox source (apt source pulls the Debian/Ubuntu source tree)
# ---------------------------------------------------------------------------
cd "$HOME"
if [ -d "firefox-build" ]; then
    rm -rf "firefox-build"
fi
mkdir -p firefox-build && cd firefox-build

# Download the source package
apt source firefox
# The directory will be something like firefox-<version>
FIREFOX_DIR=$(ls -d firefox-* 2>/dev/null | head -n 1)
if [ -z "$FIREFOX_DIR" ]; then
    echo "[!] ERROR: No firefox source directory found after apt source."
    exit 1
fi
cd "$FIREFOX_DIR"

# ---------------------------------------------------------------------------
# 4. Apply -O3 flags to the build configuration
# ---------------------------------------------------------------------------
# Firefox uses the `mach` tool which respects environment variables CFLAGS/CXXFLAGS.
# We also set DEB_* flags for the Debian packaging steps (if any).
export CFLAGS="-O3 -march=native -pipe"
export CXXFLAGS="-O3 -march=native -pipe"
export LDFLAGS="-Wl,--as-needed"

# Ensure the build system uses ccache
export CC="ccache clang-20"
export CXX="ccache clang++-20"

# ---------------------------------------------------------------------------
# 5. Bootstrap the build environment (installs python, rust, etc.)
# ---------------------------------------------------------------------------
# Bootstrap the build environment (installs python, rust, etc.)
./mach bootstrap || true

# ---------------------------------------------------------------------------
# 6. Build Firefox with -O3 optimizations
# ---------------------------------------------------------------------------
./mach build

# ---------------------------------------------------------------------------
# 7. Optional: Install the built binaries (copy to /opt/firefox-o3)
# ---------------------------------------------------------------------------
INSTALL_DIR="/opt/firefox-o3"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -a obj-x86_64-pc-linux-gnu/dist/* "$INSTALL_DIR/"

echo "===================================================================="
echo "Firefox compiled with -O3 is installed at $INSTALL_DIR"
echo "You can run it via $INSTALL_DIR/firefox"
echo "===================================================================="
