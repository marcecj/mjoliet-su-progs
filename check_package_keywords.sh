#!/usr/bin/env sh

# TODO: see if every command is necessary, perhaps one grep statement might work

if [ -f /etc/portage/package.keywords ]; then
    FILES=/etc/portage/package.keywords 
elif [ -f /etc/portage/package.accept_keywords ]; then
    FILES=/etc/portage/package.keywords 
elif [ -d /etc/portage/package.keywords  ]; then 
    FILES=$(find /etc/portage/package.keywords -type f -name \*[^~])
elif [ -d /etc/portage/package.accept_keywords  ]; then 
    FILES=$(find /etc/portage/package.accept_keywords -type f -name \*[^~])
else
    echo "No keywords file, no need to do anything."
fi

for f in $FILES; do
    # grep -v \^# ${f} | awk '{print $1}' | cut -d\~ -f2 | sed s/-\[0-9]\\+.\*//g | while read package;
    grep -v \^# ${f} | cut -d\~ -f2 | sed s/-\[0-9]\\+.\*//g | while read package;
    do
        eix --pure-packages --exact $package --format '<category>/<name>:\t<availableversions>';
    done
done
