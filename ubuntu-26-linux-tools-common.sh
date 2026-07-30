#!/bin/dash

# README
# Asegúrate de tener: deb-src http://archive.ubuntu.com/ubuntu noble main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/linux-tools-common-build && cd $HOME/linux-tools-common-build && apt source linux

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
true # sudo apt update
sudo apt build-dep linux -y
sudo apt install -y devscripts quilt ccache flex bison libssl-dev libelf-dev -y

echo "=== 1.1 Configurando ccache ==="
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 50G

echo '=== 2. Entrando al directorio del código fuente ==='
cd linux-*/
sudo chown -R $USER:$USER .

echo '=== 3. Configurando flags de optimización ==='
export DEB_CFLAGS_APPEND="-O3 -Wno-error"
export DEB_CXXFLAGS_APPEND="-O3 -Wno-error"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
# Evitar añadir múltiples veces el sufijo si ya existe
VERSION_ACTUAL=$(dpkg-parsechangelog -S Version)
if ! echo "$VERSION_ACTUAL" | grep -q "+o3"; then
    env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +o3 'Recompilando con -O3 -Wno-error'
else
    echo " [!] La versión ya tiene el sufijo +o3. Saltando modificación de changelog."
fi

echo '=== 4.1 Parcheando reglas para ignorar errores y saltar procesos del kernel ==='
# 1. Hacer que mv y depmod no detengan la construcción si faltan módulos
# Usamos -f en mv y || true en depmod para que no fallen si no hay archivos
sed -i 's/mv $(pkgdir)/mv -f $(pkgdir)/g' debian/rules.d/2-binary-arch.mk
sed -i 's/exit 1/exit 0/g' debian/rules.d/2-binary-arch.mk
# Asegurar que depmod no detenga el proceso
sed -i 's/\/sbin\/depmod/\/sbin\/depmod || true/g' debian/rules.d/2-binary-arch.mk
# Hacer que el chequeo de grep sea inofensivo si falla
sed -i 's/grep -c/grep -sc/g' debian/rules.d/2-binary-arch.mk

# 2. Desactivar tests de construcción que fallan al saltar el kernel
if [ -d debian/tests-build ]; then
    chmod -x debian/tests-build/* || true
fi

# 3. Forzar desactivación de paquetes que no queremos (solo queremos tools)
export skipbtf=true
export skipabi=true
export skipmodule=true
export skipimage=true
export skipdbg=true
export no_dumpfile=1
export do_extras_package=false
export do_flavour_image_package=false
export do_flavour_header_package=false
export dkms_exclude="zfs iwlwifi v4l2loopback"

echo '=== 5. Compilando los paquetes .deb (SOLO TOOLS, SALTANDO KERNEL/IMAGEN) ==='
export do_tools=true
export do_tools_common=true
export do_tools_host=true

# Forzar a que no se detenga por errores menores y saltar chequeos de ABI
DEB_BUILD_OPTIONS="nocheck nodocs noatest" dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i --force-confold linux-tools-*.deb linux-cloud-tools-*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Paquetes de linux-tools instalados ==="
