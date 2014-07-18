#!/bin/sh

# This is a simple script that synchronises one btrfs subvolume to another via
# rsync.  Currently it assumes that the source and target are mounted (as
# btrfs!) on the same machine, but I hope to support remote syncs in the future
# (push and/or pull; I hope both, though right now I think I'd prefer push).

die() {
    ret="$1"
    shift
    echo "$@" >&2
    exit $ret
}

if [ -z "$1" -o -z "$2" ]; then
    die 1 "Missing arguments!"
fi

src="$1"
tgt="$2"

# a temporary snapshot of the source btrfs file system
tmp_snap_dir="$src/_backup_snap/"
# the path to source subvolume on the target
tgt_snap_dir="$(echo $tgt/$src | sed s:/$::g)"

# arguments to rsync
rsync_args="-aAXi --delete --numeric-ids --delete-excluded --one-file-system --inplace --log-file=/var/log/rsync.log"

# make sure the host subvolume exists on the target
if [ ! -d "$tgt" ]
then
    /sbin/btrfs subvolume create "$tgt" \
	|| die 2 "Error creating host subvolume \"$tgt\"."

    echo "INFO: Created host subvolume \"$tgt\"."
fi

# Create the parent directory of the source subvolume, because "btrfs
# subvolume create" will not create it automatically.
tgt_snap_parent=$(echo "$tgt_snap_dir" | sed -e "s:\(.*\)/\([^/]\+/\?\):\1:g")
if [ ! -d "$tgt_snap_parent" ]; then
    mkdir -p "$tgt_snap_parent"
    echo "INFO: Created source subvolume parent \"$tgt_snap_parent\"."
fi

# make sure the source subvolume exists on the target
if [ ! -d "$tgt_snap_dir" ]
then
    /sbin/btrfs subvolume create "$tgt_snap_dir" \
	|| die 3 "Error creating source subvolume \"$tgt_snap_dir\"."

    echo "INFO: Created source subvolume \"$tgt_snap_dir\"."
fi

# create a read-only temporary snapshot of the source
/sbin/btrfs subvolume snapshot -r "$src" "$tmp_snap_dir" \
    || die 4 "Error creating temporary snapshot of \"$src\" at \"$tmp_snap_dir\"."

/usr/bin/rsync $rsync_args "$tmp_snap_dir" "$tgt_snap_dir" \
    || die 5 "Error running rsync."

/sbin/btrfs subvolume delete "$tmp_snap_dir" \
    || die 6 "Error deleting snapshot directory \"$tmp_snap_dir\"."
