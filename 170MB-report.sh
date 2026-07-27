#!/bin/bash
# Script de diagnóstico para analizar el consumo de memoria en el arranque (TTY)
# Guarda el reporte en /home/user/170MB-report.log

LOG_FILE="/home/user/170MB-report.log"

{
  echo "=================================================="
  echo "REPORTE DE USO DE MEMORIA EN EL ARRANQUE"
  echo "Fecha y hora: $(date)"
  echo "Kernel: $(uname -a)"
  echo "Cmdline del Kernel: $(cat /proc/cmdline)"
  echo "=================================================="
  echo ""

  echo "--- [1] MEMORIA GLOBAL (free -hm) ---"
  free -hm
  echo ""

  echo "--- [2] INFORMACIÓN DETALLADA DE MEMORIA (/proc/meminfo) ---"
  # Mostramos las primeras 25 líneas que son las más relevantes (MemTotal, MemFree, Active, Dirty, Slab, PageTables, etc.)
  head -n 25 /proc/meminfo
  echo ""

  echo "--- [3] MONTADOS TMPFS (Uso de RAM para almacenamiento temporal) ---"
  df -h | grep -E 'tmpfs|Filesystem'
  echo ""

  echo "--- [4] TOP 30 PROCESOS POR MEMORIA REAL (RSS) ---"
  # Formato: RAM (MB), PID, USUARIO, COMANDO
  ps -eo rss,pid,user,args --sort -rss | awk '
    NR==1 {print "  RAM_MB      PID      USER  COMMAND"}
    NR>1 {printf "%8.2f  %7d  %8s  %s\n", $1/1024, $2, $3, substr($4, 1, 80)}
  ' | head -n 31
  echo ""

  echo "--- [5] GRUPOS DE CONTROL SYSTEMD (systemd-cgtop) ---"
  if command -v systemd-cgtop >/dev/null 2>&1; then
    systemd-cgtop -n 1 -b -o memory | head -n 30
  else
    echo "systemd-cgtop no está disponible."
  fi
  echo ""

  echo "--- [6] SERVICIOS ACTIVOS DE SYSTEMD (Running Services) ---"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --state=running --no-legend --no-pager
  else
    echo "systemctl no está disponible."
  fi
  echo ""

  echo "--- [7] TAMAÑO DE LOS MÓDULOS DEL KERNEL CARGADOS (Top 20) ---"
  if [ -f /proc/modules ]; then
    sort -k3 -n -r /proc/modules | head -n 20 | awk '{printf "%-25s %8.2f KB\n", $1, $2/1024}'
  else
    echo "/proc/modules no disponible."
  fi
  echo ""

  echo "--- [8] ARCHIVOS INITRAMFS DISPONIBLES EN /boot ---"
  ls -lh /boot/initrd* /boot/initramfs* 2>/dev/null || echo "No se encontraron en /boot"
  echo ""

  echo "--- [9] TAMAÑO DE LOGS EN MEMORIA (/run/log/journal) ---"
  du -sh /run/log/journal /var/log/journal 2>/dev/null || echo "No se pudo leer el tamaño de journal"

  echo ""
  echo "==================== FIN DEL REPORTE ===================="
} > "$LOG_FILE" 2>&1

echo "Reporte generado exitosamente en $LOG_FILE"
chmod +x /home/user/170MB-report.sh
