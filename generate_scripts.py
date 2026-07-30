import os

packages = [
    "bash", "blueman", "bluez", "chromium", "coreutils", 
    "dash", "dbus", "grep", "openbox", "pipewire", 
    "procps", "wireplumber", "xbindkeys", "xinit", "xorg-server"
]

template = """#!/bin/dash

# README
# Asegúrate de tener: deb-src http://deb.debian.org/debian trixie main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/{pkg}-build && cd $HOME/{pkg}-build && apt source {pkg}

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
sudo apt update
sudo apt build-dep {pkg} -y
sudo apt install devscripts quilt -y

echo '=== 2. Entrando al directorio del código fuente ==='
cd {pkg}-*/
sudo chown -R $USER:$USER .

echo '=== 3. Configurando flags de optimización ==='
export DEB_CFLAGS_APPEND="-Ofast"
export DEB_CXXFLAGS_APPEND="-Ofast"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +ofast 'Recompilando con -Ofast'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo dpkg -i ./*.deb || sudo apt-get install -f -y

echo "=== ¡Proceso completado! Ya puedes ejecutar '{pkg}' ==="
"""

emacs_content = """#!/bin/dash

# README
# Asegúrate de tener: deb-src http://deb.debian.org/debian trixie main en sources.list
# Y haber ejecutado previamente:
# mkdir $HOME/emacs-build && cd ~/emacs-build && apt source emacs
# wget http://saravia.org/monoliths-llm/plain/emacs-30-debian-auto-build.sh -O $HOME/emacs-build/README.md
# wget http://saravia.org/bloat/plain/emacs-30/0001-frame-defaults-no-gui-bars.patch
# ahora puedes correr
# cd $HOME/emacs-build && bash README.md

set -e

echo '=== 1. Actualizando e instalando dependencias ==='
sudo apt update
sudo apt build-dep emacs -y
sudo apt install devscripts quilt -y

echo '=== 2. Entrando al directorio del código fuente ==='
cd emacs-*/
sudo chown -R $USER:$USER .

echo '=== 3. Aplicando el parche al sistema de Debian y flags de optimización ==='
# Creamos el archivo primero con la cabecera que exige Debian
echo 'Subject: Eliminar barras de la interfaz grafica' > debian/patches/0001-frame-defaults-no-gui-bars.patch
# Y luego le pegamos tu parche original debajo
cat ../0001-frame-defaults-no-gui-bars.patch >> debian/patches/0001-frame-defaults-no-gui-bars.patch

if ! grep -q '0001-frame-defaults-no-gui-bars.patch' debian/patches/series; then
    echo '0001-frame-defaults-no-gui-bars.patch' >> debian/patches/series
fi

export DEB_CFLAGS_APPEND="-Ofast"
export DEB_CXXFLAGS_APPEND="-Ofast"

echo '=== 4. Modificando el changelog para proteger el paquete ==='
rm -f debian/changelog.dch
env DEBFULLNAME='Usuario Local' DEBEMAIL='local@localhost' EDITOR=true dch --local +ofast 'Aplicado parche y compilado con -Ofast'

echo '=== 5. Compilando los paquetes .deb (IGNORANDO TESTS) ==='
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b

echo '=== 6. Instalando los paquetes generados ==='
cd ..
sudo apt install ./emacs-gtk_*_amd64.deb \\
                 ./emacs-bin-common_*_amd64.deb \\
                 ./emacs-common_*_all.deb \\
                 ./emacs-el_*_all.deb --yes

echo "=== ¡Proceso completado! Ya puedes ejecutar 'emacs' ==="
"""

os.makedirs("/home/user/monoliths-llm", exist_ok=True)
with open("/home/user/monoliths-llm/01-emacs-30-debian-auto-build.sh", "w") as f:
    f.write(emacs_content)
os.chmod("/home/user/monoliths-llm/01-emacs-30-debian-auto-build.sh", 0o755)

for i, pkg in enumerate(packages, start=2):
    filename = f"/home/user/monoliths-llm/{i:02d}-{pkg}-debian-auto-build.sh"
    with open(filename, "w") as f:
        f.write(template.format(pkg=pkg))
    os.chmod(filename, 0o755)

print("All scripts generated successfully.")
