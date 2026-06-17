#!/bin/dash

TEXT=$(yad --entry \
           --title='Translate to Spanish' \
           --text='Write something:')

[ -z "$TEXT" ] && exit 0

TRANSLATED=$("$HOME/googletrans/dist/googletrans-es" "$TEXT")

printf '%s' "$TRANSLATED" | xclip -selection clipboard
