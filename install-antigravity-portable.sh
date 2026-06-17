#!/bin/dash

TAR_FILE="antigravity-portable-libs.tar.gz"
EXTRACT_DIR="antigravity-portable-package"

# 1. Verificar que el tarball existe en el directorio actual
if [ ! -f "$TAR_FILE" ]; then
  echo "Error: No se encuentra '$TAR_FILE' en este directorio."
  exit 1
fi

echo ">> Extrayendo $TAR_FILE..."
tar -xzvf "$TAR_FILE"

echo ">> Instalando archivos de compatibilidad portables en el sistema..."
# 2. Copiar todas las bibliotecas al directorio privado de antigravity
doas mkdir -p /usr/share/antigravity/lib
doas cp -a "$EXTRACT_DIR/usr/share/antigravity/lib/." /usr/share/antigravity/lib/

# 3. Registrar el cargador dinámico en la ruta segura de sistema /lib64/
# Esto elude las restricciones de ejecución de intérpretes (Trusted Path Execution) de kernels de seguridad como Hyperbola.
echo ">> Registrando cargador dinámico en ruta de sistema segura (/lib64/ld-antigravity.so)..."
doas cp -a "$EXTRACT_DIR/usr/share/antigravity/lib/ld-linux-x86-64.so.2" /lib64/ld-antigravity.so
doas chmod 755 /lib64/ld-antigravity.so

# 4. Crear enlaces simbólicos de los recursos de Electron en el directorio lib/
# Esto es necesario porque al ejecutarse el cargador, busca sus recursos relativos a la ruta real de ejecución.
echo ">> Vinculando recursos de Electron en /usr/share/antigravity/lib/..."
doas ln -sf ../icudtl.dat /usr/share/antigravity/lib/icudtl.dat
doas ln -sf ../v8_context_snapshot.bin /usr/share/antigravity/lib/v8_context_snapshot.bin
doas ln -sf ../chrome_100_percent.pak /usr/share/antigravity/lib/chrome_100_percent.pak
doas ln -sf ../chrome_200_percent.pak /usr/share/antigravity/lib/chrome_200_percent.pak
doas ln -sf ../resources.pak /usr/share/antigravity/lib/resources.pak
doas ln -sf ../locales /usr/share/antigravity/lib/locales
doas ln -sf ../libffmpeg.so /usr/share/antigravity/lib/libffmpeg.so
doas ln -sf ../libEGL.so /usr/share/antigravity/lib/libEGL.so
doas ln -sf ../libGLESv2.so /usr/share/antigravity/lib/libGLESv2.so
doas ln -sf ../libvk_swiftshader.so /usr/share/antigravity/lib/libvk_swiftshader.so

# 5. Instalar el binario ELF original parcheado nativamente
echo ">> Instalando el binario ELF nativo pre-parcheado..."

# Hacemos una copia de respaldo del binario ELF original del sistema si no se ha hecho
if [ ! -f "/usr/share/antigravity/antigravity.original" ]; then
  if [ -f "/usr/share/antigravity/antigravity" ]; then
    # Respaldamos solo si es un binario ELF
    if file /usr/share/antigravity/antigravity | grep -q "ELF 64-bit"; then
      echo "   [+] Respaldando binario ELF original del sistema..."
      doas mv /usr/share/antigravity/antigravity /usr/share/antigravity/antigravity.original
    fi
  fi
fi

# Copiamos el binario ELF pre-parcheado al destino final de forma nativa
echo "   [+] Desplegando binario ELF pre-parcheado nativamente en /usr/share/antigravity/antigravity..."
doas cp -a "$EXTRACT_DIR/usr/share/antigravity/antigravity" /usr/share/antigravity/antigravity
doas chmod 755 /usr/share/antigravity/antigravity

# Hacemos una limpieza en caso de que existan archivos viejos de wrappers anteriores
doas rm -f /usr/share/antigravity/antigravity.binary

# 6. Configurar el launcher público /usr/bin/antigravity como enlace simbólico
echo ">> Configurando el launcher público /usr/bin/antigravity como un enlace simbólico..."
doas rm -f /usr/bin/antigravity
doas ln -sf /usr/share/antigravity/bin/antigravity /usr/bin/antigravity

# 7. Limpiar archivos temporales
rm -rf "$EXTRACT_DIR"

echo "¡Instalación y configuración del entorno portable de antigravity completada con éxito!"
