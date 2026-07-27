#!/bin/bash

# Find first available wireless interface (e.g., wlan0, wlan1)
WIFI_INTF=$(ip -o link show | awk -F': ' '{print $2}' | grep '^wlan' | head -n 1)

if [ -n "$WIFI_INTF" ]; then
    echo "Using wireless interface: $WIFI_INTF"

    doas killall wpa_supplicant

    doas dhcpcd -k

    if [ -e /var/run/wpa_supplicant/$WIFI_INTF ]; then
	doas rm /var/run/wpa_supplicant/$WIFI_INTF
    fi

    doas ip link set $WIFI_INTF up

    doas wpa_supplicant -B -i $WIFI_INTF -c /etc/wpa_supplicant/wpa_supplicant.conf

    sleep 5

    doas dhcpcd -G $WIFI_INTF

    sleep 1

    doas dhcpcd -4 $WIFI_INTF
else
    echo "No wireless interface (wlan*) found. Reconnect your USB adapter or load the driver."
fi
