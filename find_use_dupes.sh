#!/bin/sh

echo "\n(Potentialy) duplicated USE flags found:\n"
grep USE= /etc/make.conf | cut -d\" -f2 | tr ' ' '\n' | while read USE_FLAG;
do
    FINDS="$(grep --color "^[^#].* $USE_FLAG\([[:space:]]\|$\)\{1,\}" /etc/portage/package.use/*[!\~])"
    if [ -n "$FINDS" ]; then
	echo "$USE_FLAG:\n$FINDS"
    fi
done
