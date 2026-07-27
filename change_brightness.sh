#!/bin/sh
action=$1
curr=$(xrandr --verbose | grep -m 1 -i brightness | awk '{print $2}')

if [ "$action" = "up" ]; then
    new=$(awk -v c="$curr" 'BEGIN {new = c + 0.05; print (new > 1.0 ? 1.0 : new)}')
else
    new=$(awk -v c="$curr" 'BEGIN {new = c - 0.05; print (new < 0.1 ? 0.1 : new)}')
fi

xrandr --output eDP-1 --brightness "$new"
