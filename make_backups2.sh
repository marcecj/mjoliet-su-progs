SOURCES="/
/home
/home/marcec/VBoxDrives
/home/marcec/multimedia"
BACKUP_DIR="/media/MARCEC_BACKUP"
TARGET="$BACKUP_DIR/$(hostname)2"

#
# handle options
#

init=0
while getopts i a;
do
    case $a in
        i) init=1;;
    esac
done
shift $(expr $OPTIND - 1)

prefix="$1"
count="$2"
if [ -z "$prefix" -o -z "$count" ]; then
    echo "Missing arguments!" >&2
    exit 1
fi

if [ ! -d "$TARGET" ];
then
    echo "Non-existent target!"
    exit
fi

#
# define helper functions
#

init_target_subvolumes() {
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

transfer_subvolume() {
    local src="$1"
    local tgt="$2"
    local num_snapshots="$(ls -1 -d $src/.snapshot/${prefix}* | wc -l)"
    local current_snapshot="$(ls -1 -d --sort=time $src/.snapshot/${prefix}* | tail -n1)"
    local parent_snapshot="$(ls -1 -d --sort=time $src/.snapshot/${prefix}* | tail -n2 | head -n1)"

    if [ "$num_snapshots" -ge 2 ]; then
	btrfs send -p "$parent_snapshot" "$current_snapshot" | btrfs receive "$tgt"
    else
	btrfs send "$current_snapshot" | btrfs receive "$tgt"
    fi
}

non_hourly_backups() {
    echo "Note implemented yet"
    return

    local tgt="$1"
    local oldest_snapshot=""

    if [ "$prefix" = "daily" ]; then
	oldest_snapshot="$(ls -1 -d --sort=time ${tgt}/hourly* | tail -n1)"
    elif [ "$prefix" = "weekly" ]; then
	oldest_snapshot="$(ls -1 -d --sort=time ${tgt}/daily* | tail -n1)"
    elif [ "$prefix" = "monthly" ]; then
	oldest_snapshot="$(ls -1 -d --sort=time ${tgt}/weekly* | tail -n1)"
    fi

    btrfs-snap -r -b "$tgt" "$prefix" "$count"

    if [ ! -z "$oldest_snapshot" -a "$prefix" = "hourly" ]; then
	btrfs subvolume delete "$oldest_snapshot"
    fi
}

del_current_snapshot() {
    src="$1"
    local num_snapshots="$(ls -1 -d $src/.snapshot/${prefix}* | wc -l)"
    local current_snapshot="$(ls -1 -d --sort=time $src/.snapshot/${prefix}* | tail -n1)"
    if [ "$num_snapshots" -ge 2 ]; then
	btrfs subvolume delete "$current_snapshot"
    fi
}

if [ "$init" -eq 1 ]; then
    init_target_subvolumes
    exit
fi

echo "$SOURCES" | while read d;
do
    if [ ! -d "$d" ]; then
        echo "Non-existent source!"
        exit 1
    fi

    # make a snapshot of the source volume; we only need to keep two around for
    # incremental send/receive
    btrfs-snap -r "$d" "$prefix" 2

    if [ $? -ne 0 ]; then
	echo "\tError creating snapshot." >&2
	exit 2
    fi

    tgt="${TARGET}${d}/.snapshot"

    echo "Transferring snapshot of '$d' to '$tgt'"
    transfer_subvolume "$d" "$tgt"

    if [ $? -ne 0 ]; then
	echo "\tError transferring, continuing with next target." >&2

	echo "" >&2
	echo "\tTo prevent breaking the chain of snapshots," >&2
	echo "\tthe most recent one will be deleted." >&2

	del_current_snapshot "$d"

	continue
    fi

    non_hourly_backups "$tgt"

    echo "******"
done
