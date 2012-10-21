#!/bin/sh
#
# Note that you should have your PATH specified correctly for the commands in
# this script to be able to launch.
#
# Changelog:
#   06.01.2008 - finally fixed this so it finds all modules
#   25.03.2012 - convert to POSIX shell

MODULES_PATH="/lib/modules/$(uname -r)/"
MODS=""

lsmod | awk '{print $1".ko"}' | sed 's/^Module//' | {
while read MOD;
do
    NEW_MOD=$(find $MODULES_PATH -iname $MOD)
    # Sometimes a module name will contain underscores instead of dashes. This
    # accommodates for those cases.
    if [ ! -n "$NEW_MOD" ];
    then 
	NEW_MOD=$(find $MODULES_PATH -iname $(echo "$MOD" | tr _ -))
    fi
    echo "$NEW_MOD"
done | uniq | tr '\n' '\0' | du -hsc --files0-from=- 2>/dev/null | sort -h $@
}
