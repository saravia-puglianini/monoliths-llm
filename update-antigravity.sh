#!/bin/dash

# Detectar si es Gentoo
if [ -f /etc/os-release ] && grep -qi "gentoo" /etc/os-release; then
    echo "solo se puede instalar"
    exit 1
fi

[ -d "$HOME/monoliths-llm/antigravity-package" ] && doas mv "$HOME/monoliths-llm/antigravity-package" /tmp/
mkdir -p "$HOME/monoliths-llm/antigravity-package/usr/bin"
mkdir -p "$HOME/monoliths-llm/antigravity-package/usr/share"
doas cp -v /usr/bin/antigravity antigravity-package/usr/bin/
doas cp -rv /usr/share/antigravity antigravity-package/usr/share/
cd "$HOME/monoliths-llm"
[ -f "$HOME/monoliths-llm/antigravity.tar.gz" ] && mv "$HOME/monoliths-llm/antigravity.tar.gz" /tmp/
cd "$HOME/monoliths-llm"
tar -czvf antigravity.tar.gz antigravity-package
[ -f antigravity.tar.gz ] && echo 'antigravity.tar.gz actualizado!!!'