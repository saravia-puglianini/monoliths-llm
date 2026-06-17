#!/bin/dash

# =============================================================================
# Script: ubuntu-run-all.sh
# Descripción: Recompila todos los paquetes (01-16) con optimización -O3
#              específicamente para Ubuntu. Crea sus carpetas de trabajo y
#              gestiona las fuentes automáticamente.
# =============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Configuración de rutas
VENDOR_NAME=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr ' ' '_' | tr '[:upper:]' '[:lower:]' || echo "generic")
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr ' ' '_' | tr '[:upper:]' '[:lower:]' || echo "model")
MODEL_DIR="${VENDOR_NAME}_${PRODUCT_NAME}"

BASE_DIR="$HOME/ubuntu-recompile-workspace/$MODEL_DIR"
SCRIPTS_DIR="/home/user/monoliths-llm"

# Asegurar que la carpeta base existe
mkdir -p "$BASE_DIR"

echo "--- Asegurando configuración térmica para compilación ($VENDOR_NAME) ---"
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
# =============================================================================

echo "========================================================================"
echo "   PREPARANDO REPOSITORIOS (HABILITANDO deb-src)                       "
echo "========================================================================"
sudo sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
# Agregar PPA de Chromium en deb (para evitar el paquete snap "chromium-browser")
sudo add-apt-repository ppa:xtradeb/apps -y
sudo sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list.d/xtradeb-ubuntu-apps-*.list || true
sudo apt update -y || true
sudo apt install -y ccache

# Configuración global de ccache
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 50G
echo "--- ccache configurado (50GB) ---"


# Lista de scripts en orden de ejecución
SCRIPTS="
ubuntu-01-emacs-29.sh
ubuntu-02-bash.sh
ubuntu-03-blueman.sh
ubuntu-04-bluez.sh
ubuntu-06-coreutils.sh
ubuntu-07-dash.sh
ubuntu-08-dbus.sh
ubuntu-09-grep.sh
ubuntu-10-openbox.sh
ubuntu-11-pulseaudio.sh
ubuntu-12-procps.sh
ubuntu-13-pavucontrol.sh
ubuntu-13-wireplumber.sh
ubuntu-14-xbindkeys.sh
ubuntu-15-xinit.sh
ubuntu-16-xorg-server.sh
ubuntu-17-network-manager.sh
ubuntu-19-gnome-shell.sh
ubuntu-20-thermald.sh
ubuntu-21-acpid.sh
ubuntu-22-avahi-daemon.sh
ubuntu-23-openfortivpn.sh
ubuntu-24-htop.sh
ubuntu-25-gimp.sh
ubuntu-26-linux-tools-common.sh
ubuntu-27-linux-tools-generic.sh
"

echo "========================================================================"
echo "   INICIANDO RECOMPILACIÓN TOTAL DEL SISTEMA (UBUNTU - DASH)           "
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

    # Extraer el nombre del paquete quitando 'ubuntu-XX-' y '.sh'
    # Ejemplo: ubuntu-07-dash.sh -> dash
    pkg_id=$(echo "$script_name" | sed 's/^ubuntu-[0-9]\+-//; s/\.sh$//')
    
    build_dir="$BASE_DIR/${pkg_id}-build"
    mkdir -p "$build_dir"
    
    echo ""
    echo ">>> PROCESANDO: $pkg_id"
    echo "------------------------------------------------------------------------"
    
    cd "$build_dir"

    # Fix específico para wireplumber (evitar conflicto con pipewire-media-session)
    if [ "$pkg_id" = "wireplumber" ]; then
        if dpkg -l | grep -q pipewire-media-session; then
            echo " [!] Eliminando pipewire-media-session para permitir wireplumber..."
            sudo apt-get remove -y pipewire-media-session || true
        fi
    fi

    # Repositorio extra para Emacs (si fuera necesario, pero ahora usamos fuentes para 29)
    if [ "$pkg_id" = "emacs-29" ]; then
        echo " [!] Emacs 29 se compila desde fuentes para asegurar compatibilidad con GCC 11."
    fi

    # Si ya existen archivos .deb, verificar si ya están instalados
    if ls *.deb >/dev/null 2>&1; then
        echo " [✓] Paquetes ya compilados para $pkg_id. Verificando estado..."
        
        DEBS_TO_INSTALL=""
        NEED_INSTALL=0
        
        for f in *.deb; do
            # Verificar si el archivo está vacío o es inválido
            if [ ! -s "$f" ]; then
                rm -f "$f"
                continue
            fi

            P_NAME=$(dpkg-deb -f "$f" Package 2>/dev/null || true)
            P_VER=$(dpkg-deb -f "$f" Version 2>/dev/null || true)
            [ -z "$P_NAME" ] && rm -f "$f" && continue

            # Verificar si está instalado y qué versión tiene
            INST_VER=$(dpkg-query -W -f='${Version}' "$P_NAME" 2>/dev/null || true)
            INST_STATUS=$(dpkg-query -W -f='${Status}' "$P_NAME" 2>/dev/null || true)
            IS_INSTALLED=0
            if echo "$INST_STATUS" | grep -q "ok installed"; then
                IS_INSTALLED=1
            fi

            # Lógica de filtrado para evitar instalar paquetes conflictivos que no queremos
            case "$P_NAME" in
                emacs-gtk)
                    # Prioridad: instalar siempre la versión GTK
                    DEBS_TO_INSTALL="$DEBS_TO_INSTALL ./$f"
                    if [ "$IS_INSTALLED" -eq 0 ] || [ "$INST_VER" != "$P_VER" ]; then
                        NEED_INSTALL=1
                    fi
                    ;;
                emacs-lucid|emacs-nox)
                    # Solo incluir si ya está instalado Y no estamos forzando GTK
                    # (Si se incluyen varios que confictúan, apt fallará o hará cosas raras)
                    if [ "$IS_INSTALLED" -eq 1 ]; then
                        # Si existe un .deb de gtk en la misma carpeta, omitimos nox/lucid para favorecer gtk
                        if ! ls emacs-gtk_*.deb >/dev/null 2>&1; then
                            DEBS_TO_INSTALL="$DEBS_TO_INSTALL ./$f"
                            [ "$INST_VER" != "$P_VER" ] && NEED_INSTALL=1
                        else
                            echo " [!] Saltando $P_NAME porque se ha detectado emacs-gtk (preferido)."
                        fi
                    fi
                    ;;
                linux-image-*|linux-headers-*|linux-modules-*|linux-buildinfo-*|linux-source-*|linux-cloud-tools-*)
                    # Solo incluir si ya está instalado (evitamos instalar kernel accidentalmente)
                    if [ "$IS_INSTALLED" -eq 1 ]; then
                        DEBS_TO_INSTALL="$DEBS_TO_INSTALL ./$f"
                        [ "$INST_VER" != "$P_VER" ] && NEED_INSTALL=1
                    fi
                    ;;
                *)
                    # Por defecto incluir todos los .deb del paquete
                    DEBS_TO_INSTALL="$DEBS_TO_INSTALL ./$f"
                    if [ "$IS_INSTALLED" -eq 0 ] || [ "$INST_VER" != "$P_VER" ]; then
                        NEED_INSTALL=1
                    fi
                    ;;
            esac
        done

        if [ "$NEED_INSTALL" -eq 0 ] && [ -n "$DEBS_TO_INSTALL" ]; then
            echo " [✓] Todos los componentes de $pkg_id ya están al día. Saltando."
        elif [ -n "$DEBS_TO_INSTALL" ]; then
            echo " [!] Instalando componentes de $pkg_id (con --allow-downgrades)..."
            # Usar 'apt install' con --allow-downgrades para manejar versiones personalizadas
            sudo apt-get install -y --allow-downgrades -o Dpkg::Options::="--force-confold" $DEBS_TO_INSTALL || sudo apt-get install -f -y
        else
            echo " [?] No se encontraron paquetes ya instalados que coincidan con los .deb de $pkg_id."
        fi
        echo "------------------------------------------------------------------------"
        continue
    fi

    apt_pkg="$pkg_id"
    if [ "$pkg_id" = "emacs-29" ]; then
        apt_pkg="emacs29"
    elif [ "$pkg_id" = "chromium" ]; then
        apt_pkg="chromium"
    elif [ "$pkg_id" = "linux-tools-common" ]; then
        apt_pkg="linux"
    elif [ "$pkg_id" = "linux-tools-generic" ]; then
        apt_pkg="linux-meta"
    fi

    found_src=0
    for d in "$pkg_id"-* "$apt_pkg"-*; do
        if [ -d "$d" ]; then
            found_src=1
            break
        fi
    done

    if [ "$found_src" -eq 0 ]; then
        if [ "$pkg_id" = "emacs-29" ]; then
            echo " [!] Saltando 'apt source' para emacs-29 (el sub-script descargará desde GNU)."
        else
            echo "Descargando código fuente de $apt_pkg..."
            apt source "$apt_pkg"
        fi
    fi

    if [ "$pkg_id" = "emacs-29" ] && [ ! -f "0001-frame-defaults-no-gui-bars.patch" ]; then
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
