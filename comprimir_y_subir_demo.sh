#!/bin/bash
# ==============================================================================
# Script: comprimir_y_subir_demo.sh
# Comprime ~/blob, ~/optime y ~/bloat chancando sus respectivos .tar.gz en ~
# y los sube via scp a demo:~/public/ usando la contraseña configurada.
# ==============================================================================

# Si XYZ está vacío, cargar las variables de entorno de /etc/profile
if [ -z "$XYZ" ]; then
    if [ -f /etc/profile ]; then
        . /etc/profile
    fi
fi

echo "========================================================"
echo "    Iniciando Compresión y Subida a demo:~/public/     "
echo "========================================================"
echo ""

# 1. Comprimir y chancar archivos en $HOME
echo "--> Comprimiendo ~/blob -> ~/blob.tar.gz ..."
tar -czf "$HOME/blob.tar.gz" -C "$HOME" blob
echo "    [OK] ~/blob.tar.gz creado."

echo "--> Comprimiendo ~/optime -> ~/optime.tar.gz ..."
tar -czf "$HOME/optime.tar.gz" -C "$HOME" optime
echo "    [OK] ~/optime.tar.gz creado."

echo "--> Comprimiendo ~/bloat -> ~/bloat.tar.gz ..."
tar -czf "$HOME/bloat.tar.gz" -C "$HOME" bloat
echo "    [OK] ~/bloat.tar.gz creado."

echo ""
echo "--> Obteniendo credenciales de acceso..."

PERSONAL_DIR=$(cat "$HOME/.personal" 2>/dev/null)
PASS_BASE="$HOME/$PERSONAL_DIR"
PASS_FILE=""

if [ -f "$PASS_BASE/${USER}.${XYZ}.${USER}" ]; then
    PASS_FILE="$PASS_BASE/${USER}.${XYZ}.${USER}"
elif [ -f "$PASS_BASE/${USER}.libre.${XYZ}.${USER}" ]; then
    PASS_FILE="$PASS_BASE/${USER}.libre.${XYZ}.${USER}"
else
    PASS_FILE=$(ls "$PASS_BASE"/*"$XYZ"* 2>/dev/null | head -n 1)
fi

if [ -z "$PASS_FILE" ] || [ ! -f "$PASS_FILE" ]; then
    echo "[!] Error: No se encontró el archivo de contraseña en $PASS_BASE con XYZ."
    exit 1
fi

SSH_PASS=$(cat "$PASS_FILE")

echo "--> Subiendo archivos a demo:~/public/ mediante scp..."

expect - <<EOF
set timeout 600
set password "$SSH_PASS"

spawn scp "$HOME/blob.tar.gz" "$HOME/optime.tar.gz" "$HOME/bloat.tar.gz" demo:~/public/
expect {
    -nocase "are you sure you want to continue connecting" {
        send "yes\r"
        exp_continue
    }
    -nocase "password:" {
        send "\$password\r"
        exp_continue
    }
    eof
}
catch wait result
set exit_status [lindex \$result 3]
exit \$exit_status
EOF

STATUS=$?
echo ""
if [ $STATUS -eq 0 ]; then
    echo "========================================================"
    echo "  [EXITO] Todos los archivos fueron subidos a demo:~/public/"
    echo "========================================================"
else
    echo "========================================================"
    echo "  [ERROR] Falló la subida (código de salida: $STATUS)"
    echo "========================================================"
fi

# Pequeña pausa para visualización antes de cerrar la ventana de terminal
sleep 2
exit $STATUS
