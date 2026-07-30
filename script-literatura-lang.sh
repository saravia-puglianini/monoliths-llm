#!/bin/dash

CONT="$1"

# TO SPANISH
if ! cat $HOME/monoliths-llm/script-literatura-core.sh | grep '#VERSION=' | grep -iq es_MX; then
    if [ -f "$HOME/googletrans/dist/googletrans-es" ]; then
	CONT=$($HOME/googletrans/dist/googletrans-es "$CONT")
    fi
fi

# TO SPANISH NOT INTERNET BUT LAN ASUS
if false; then
    CONT=$(printf '%s\n' "$CONT" \
	       | ssh -o LogLevel=ERROR $(cat ~/.asdf)@$(cat ~/.fdsa) "apertium eng-spa" \
	       | tr -d '*' | tr -d '#')
fi

# TO GERMAN
if ! cat $HOME/monoliths-llm/script-literatura-core.sh | grep '#VERSION=' | grep -iq de_DE; then
    if [ -f "$HOME/googletrans/dist/googletrans-de" ]; then
	CONT=$($HOME/googletrans/dist/googletrans-de "$CONT")
    fi
fi

echo -n "$CONT"