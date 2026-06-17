#!/bin/bash
set -e

echo "=== 1. Instalando dependencias ==="
sudo apt update
sudo apt install -y build-essential libx11-dev libxft-dev libxext-dev

echo "=== 2. Descargando st ==="
cd $HOME
rm -rf st
git clone https://git.suckless.org/st
cd st

echo "=== 3. Configurando colores (fondo blanco / texto negro) ==="
cp config.def.h config.h

# Cambiar esquema por defecto: fondo blanco, texto negro
sed -i 's/"gray90", \/\* default foreground colour \*\//"black", \/\* default foreground colour \*\//' config.h
sed -i 's/"black", \/\* default background colour \*\//"white", \/\* default background colour \*\//' config.h

echo "=== 4. Compilando ==="
make

echo "=== 5. Instalando ==="
sudo make install

echo "=== Listo. Ejecuta 'st' ==="
