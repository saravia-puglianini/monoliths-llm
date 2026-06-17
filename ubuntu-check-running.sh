#!/bin/dash

# List of already optimized packages (scripts 01-22)
OPTIMIZED="emacs bash blueman bluez chromium-browser coreutils dash dbus grep openbox pulseaudio procps pavucontrol wireplumber xbindkeys xinit xorg-server network-manager conky-all gnome-shell thermald acpid avahi-daemon shell"

echo "=== Análisis de Optimización -O3 (Ubuntu) ==="
printf "\033[1;34m%-25s %-25s %-10s\033[0m\n" "PROCESO" "PAQUETE" "ESTADO"
echo "----------------------------------------------------------------------"

# Use ps to list processes
ps -e -o comm= | sort -u | while read proc; do
    # Skip kernel threads and helper scripts
    case "$proc" in
        kworker*|migration*|idle_inject*|cpuhp*|rcu*|ps|sort|dash|bash|sh|grep|sed|awk|ls|cat|command-v|which) continue ;;
    esac

    # Find the package
    pkg=$(dpkg-query -l "$proc" 2>/dev/null | grep "^ii" | awk '{print $2}' | head -n1)
    if [ -z "$pkg" ]; then
        bin_path=$(which "$proc" 2>/dev/null)
        if [ -n "$bin_path" ]; then
            pkg=$(dpkg-query -S "$bin_path" 2>/dev/null | cut -d: -f1 | head -n1)
        fi
    fi

    if [ -n "$pkg" ]; then
        is_opt="FALTA"
        for opt in $OPTIMIZED; do
            if [ "$pkg" = "$opt" ] || [ "$proc" = "$opt" ]; then
                is_opt="OPTIMIZADO"
                break
            fi
        done
        
        if [ "$is_opt" = "OPTIMIZADO" ]; then
            printf "%-25s %-25s \033[1;32m%s\033[0m\n" "$proc" "$pkg" "$is_opt"
        else
            printf "%-25s %-25s \033[1;31m%s\033[0m\n" "$proc" "$pkg" "$is_opt"
        fi
    fi
done | sort -u
