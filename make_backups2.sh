#!/bin/sh

DEFAULT_SOURCES="/
/home
/home/marcec/VBoxDrives
/home/marcec/multimedia"
SOURCES="${SOURCES:-$DEFAULT_SOURCES}"
BACKUP_DIR="${BACKUP_DIR:-/media/MARCEC_BACKUP}"
TARGET="$BACKUP_DIR/$(hostname)2"

#
# handle options
#

init_target_subvolumes() {
    echo "LOG: Initialising target subvolumes"

    echo "$SOURCES" | while read d;
    do
	local tgt="${TARGET}/${d}"

	if [ ! -d "$tgt" ]; then
	    # Create the parent directory of the source subvolume, because "btrfs
	    # subvolume create" will not create it automatically.
	    local tgt_snap_parent=$(echo "$tgt" | sed -e "s:\(.*\)/\([^/]\+/\?\):\1:g")
	    if [ ! -d "$tgt_snap_parent" ]; then
		mkdir -p "$tgt_snap_parent"
		echo "INFO: Created source subvolume parent \"$tgt_snap_parent\"."
	    fi

	    btrfs subvolume create "$tgt"
	fi

	if [ ! -d "$tgt/.snapshot" ]; then
	    mkdir "$tgt/.snapshot"
	    echo "INFO: Created snapshot directory \""$tgt"/.snapshot\"."
	fi
    done
}

while getopts i a;
do
    case $a in
        i) init_target_subvolumes; exit;;
    esac
done
shift $(expr $OPTIND - 1)

prefix="$1"
count="$2"
if [ -z "$prefix" -o -z "$count" ]; then
    echo "Missing arguments!" >&2
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Non-existent target!" >&2
    exit 2
fi

#
# define helper functions
#

# transfers the subvolume, incrementally if a parent subvolume exists
transfer_subvolume() {
    local src="$1"
    local tgt="$2"
    local num_snapshots="$(ls -1d $src/.snapshot/${prefix}* | wc -l)"
    local current_snapshot="$(ls -1d $src/.snapshot/${prefix}* | tail -n1)"
    local parent_snapshot="$(ls -1d $src/.snapshot/${prefix}* | tail -n2 | head -n1)"

    echo "LOG: Transferring snapshot of '$src' to '$tgt'"

    if [ "$num_snapshots" -ge 2 ]; then
	btrfs send -p "$parent_snapshot" "$current_snapshot" | btrfs receive "$tgt"
    else
	btrfs send "$current_snapshot" | btrfs receive "$tgt"
    fi
}

# rotates the oldest snapshot of a prefix to the next prefix (e.g., the oldest
# hourly snapshot becomes the newest daily snapshot)
rotate_prefix() {
    local tgt="$1"
    local old_prefix=""

    case "$prefix" in
	"hourly") return;;
	"daily") old_prefix="hourly";;
	"weekly") old_prefix="daily";;
	"monthly") old_prefix="weekly";;
    esac

    local old_snapshot="$(ls -1d ${tgt}/${old_prefix}* | head -n1)"
    local new_snapshot=$(echo "$old_snapshot" | sed -e "s:${old_prefix}_\([^/]\+\):${prefix}_\1:g")

    if [ -d "$new_snapshot" ]; then
	echo "INFO: already made daily snapshot."
	return
    fi

    btrfs subvolume snapshot -r "$old_snapshot" "$new_snapshot"
}

# deletes the oldest snapshot of the selected prefix when necessary
del_oldest_snapshot() {
    local tgt="$1"
    local num_snapshots="$(ls -1d $tgt/${prefix}* | wc -l)"
    local num_to_delete="$(($num_snapshots - $count))"
    local oldest_snapshots="$(ls -1d $tgt/${prefix}* | head -n$num_to_delete)"

    if [ "$num_snapshots" -gt "$count" ]; then
	echo "LOG: deleting oldest snapshot."
	echo "$oldest_snapshots" | while read s; do
	    btrfs subvolume delete "$s"
	done
    fi
}

# deletes the most recently made snapshot (on the *source* subvolume!)
del_current_snapshot() {
    local src="$1"
    local num_snapshots="$(ls -1d $src/.snapshot/${prefix}* | wc -l)"
    local current_snapshot="$(ls -1d $src/.snapshot/${prefix}* | tail -n1)"

    if [ "$num_snapshots" -ge 2 ]; then
	btrfs subvolume delete "$current_snapshot"
    fi
}

#
# perform the backup
#

echo "$SOURCES" | while read d;
do
    if [ ! -d "$d" ]; then
        echo "Non-existent source!" >&2
        exit 3
    fi

    tgt="${TARGET}${d}/.snapshot"

    if [ "$prefix" = "hourly" ];
    then
	# make a snapshot of the source volume; we only need to keep two around for
	# incremental send/receive
	btrfs-snap -r "$d" "$prefix" 2

	if [ $? -ne 0 ]; then
	    echo "\tError creating snapshot." >&2
	    exit 4
	fi

	transfer_subvolume "$d" "$tgt"

	if [ $? -ne 0 ]; then
	    echo "\tError transferring, continuing with next target." >&2
	    echo "" >&2
	    echo "\tTo prevent breaking the chain of snapshots," >&2
	    echo "\tthe most recent one will be deleted." >&2

	    del_current_snapshot "$d"

	    continue
	fi
    fi

    rotate_prefix "$tgt"

    del_oldest_snapshot "$tgt"

    echo "******"
done
