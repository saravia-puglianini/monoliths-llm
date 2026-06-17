#!/bin/dash

# =============================================================================
# Script: debian-run-all.sh
# Descripción: Recompila todos los paquetes (01-16) con optimización -O3
#              específicamente para Debian. Crea sus carpetas de trabajo y
#              gestiona las fuentes automáticamente.
# =============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Configuración de rutas
VENDOR_NAME=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr ' ' '_' | tr '[:upper:]' '[:lower:]' || echo "generic")
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr ' ' '_' | tr '[:upper:]' '[:lower:]' || echo "model")
MODEL_DIR="${VENDOR_NAME}_${PRODUCT_NAME}"

BASE_DIR="$HOME/debian-recompile-workspace/$MODEL_DIR"
SCRIPTS_DIR="/home/user/monoliths-llm"

# Asegurar que la carpeta base existe
mkdir -p "$BASE_DIR"

# =============================================================================
# GESTIÓN DE ENFRIAMIENTO (ICE MODE)
# Solo se ejecuta si no está activo ya (validando no_turbo) para no pedir sudo mil veces.
# =============================================================================
ICE_ACTIVE=0
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    [ "$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)" = "1" ] && ICE_ACTIVE=1
elif [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
    [ "$(cat /sys/devices/system/cpu/cpufreq/boost)" = "0" ] && ICE_ACTIVE=1
fi

if [ "$ICE_ACTIVE" -eq 0 ]; then
    echo "--- Validando hardware para enfriamiento ($VENDOR_NAME) ---"
    case "$VENDOR_NAME" in
        *hp*)
            echo "[!] Detectada laptop HP. Aplicando configuración térmica..."
            /bin/dash "$SCRIPTS_DIR/enfriar-hp.sh"
            ;;
        *asus*)
            echo "[!] Detectada laptop Asus. Aplicando configuración térmica..."
            /bin/dash "$SCRIPTS_DIR/enfriar-asus.sh"
            ;;
        *)
            echo "[?] Marca '$VENDOR_NAME' no tiene script específico. Se recomienda enfriamiento manual."
            ;;
    esac
else
    echo "--- Modo hielo ya activo. Saltando configuración térmica ---"
fi
# =============================================================================

echo "========================================================================"
echo "   PREPARANDO REPOSITORIOS (HABILITANDO deb-src)                       "
echo "========================================================================"
sudo sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
true # sudo apt update -y || true


# Lista de scripts en orden de ejecución
# debian-05-chromium.sh
SCRIPTS="
debian-01-emacs-30.sh
debian-02-bash.sh
debian-03-blueman.sh
debian-04-bluez.sh
debian-06-coreutils.sh
debian-07-dash.sh
debian-08-dbus.sh
debian-09-grep.sh
debian-10-openbox.sh
debian-11-pipewire.sh
debian-12-procps.sh
debian-13-wireplumber.sh
debian-14-xbindkeys.sh
debian-15-xinit.sh
debian-16-xorg-server.sh
<<<<<<< HEAD
debian-17-pavucontrol.sh
debian-18-network-manager.sh
debian-19-conky-all.sh
debian-20-gnome-shell.sh
debian-21-thermald.sh
debian-22-acpid.sh
debian-23-avahi-daemon.sh
debian-24-gimp.sh
debian-25-htop.sh
debian-26-openfortivpn.sh
=======
debian-17-openfortivpn.sh
debian-18-htop.sh
debian-19-gimp.sh
debian-20-linux-tools-common.sh
debian-21-linux-tools-generic.sh
>>>>>>> 9654973b48fad4b22fee65b13e50c69c5c2121c7
"

echo "========================================================================"
echo "   INICIANDO RECOMPILACIÓN TOTAL DEL SISTEMA (DEBIAN - DASH)           "
echo "========================================================================"
echo "Carpeta de trabajo: $BASE_DIR"
echo "Scripts fuente:     $SCRIPTS_DIR"
echo "========================================================================"

for script_name in $SCRIPTS; do
    script_name=$(echo "$script_name" | xargs)
    [ -z "$script_name" ] && continue

    script_path="$SCRIPTS_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        echo " [!] Saltando: No se encontró el archivo $script_path"
        continue
    fi

    # Extraer el nombre del paquete quitando 'debian-XX-' y '.sh'
    pkg_id=$(echo "$script_name" | sed 's/^debian-[0-9]\+-//; s/\.sh$//')
    
    build_dir="$BASE_DIR/${pkg_id}-build"
    mkdir -p "$build_dir"
    
    echo ""
    echo ">>> PROCESANDO: $pkg_id"
    echo "------------------------------------------------------------------------"
    
    cd "$build_dir"

    # Si ya existen archivos .deb, verificar si ya están instalados
    if ls *.deb >/dev/null 2>&1; then
        echo " [✓] Paquetes ya compilados para $pkg_id. Verificando estado..."
        
        ALL_INSTALLED=1
        for f in *.deb; do
            PKG_NAME=$(dpkg-deb -f "$f" Package)
            if ! dpkg-query -W -f='${Status}' "$PKG_NAME" 2>/dev/null | grep -q "ok installed"; then
                ALL_INSTALLED=0
                break
            fi
        done

        if [ "$ALL_INSTALLED" -eq 1 ]; then
            echo " [✓] Todos los componentes de $pkg_id ya están instalados. Saltando."
        else
            echo " [!] Algunos componentes de $pkg_id faltan o están incompletos. Instalando..."
            sudo apt-get install -y -o Dpkg::Options::="--force-confold" ./*.deb || sudo apt-get install -f -y
        fi
        echo "------------------------------------------------------------------------"
        continue
    fi

    apt_pkg="$pkg_id"
    if [ "$pkg_id" = "emacs-30" ]; then
        apt_pkg="emacs"
<<<<<<< HEAD
    elif [ "$pkg_id" = "conky-all" ]; then
        apt_pkg="conky"
    elif [ "$pkg_id" = "avahi-daemon" ]; then
        apt_pkg="avahi"
=======
    elif [ "$pkg_id" = "linux-tools-common" ]; then
        apt_pkg="linux"
    elif [ "$pkg_id" = "linux-tools-generic" ]; then
        apt_pkg="linux-meta"
>>>>>>> 9654973b48fad4b22fee65b13e50c69c5c2121c7
    fi

    found_src=0
    for d in "$pkg_id"-* "$apt_pkg"-*; do
        if [ -d "$d" ]; then
            found_src=1
            break
        fi
    done

    if [ "$found_src" -eq 0 ]; then
        echo "Descargando código fuente de $apt_pkg..."
        apt source "$apt_pkg"
    fi

    if [ "$pkg_id" = "emacs-30" ] && [ ! -f "0001-frame-defaults-no-gui-bars.patch" ]; then
        echo "Descargando parche de interfaz para Emacs..."
        wget -q http://saravia.org/bloat/plain/emacs-30/0001-frame-defaults-no-gui-bars.patch || echo "Error al bajar parche"
    fi

    echo "Iniciando compilación (esto puede tardar, especialmente chromium)..."
    /bin/dash "$script_path"

    echo "------------------------------------------------------------------------"
    echo ">>> FINALIZADO: $pkg_id"
    
done

echo ""
echo "========================================================================"
echo "   RECOMPILACION COMPLETADA EXITOSAMENTE                               "
echo "========================================================================"
