SOURCES="/home/marcec/VBoxDrives
/home/marcec/multimedia
/home
/"
BACKUP_DIR="/run/media/marcec/MARCEC_BACKUP"
TARGET="$BACKUP_DIR/$(hostname)"

sync=0
while getopts s a;
do
    case $a in
        s) sync=1;;
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

echo "$SOURCES" | while read d;
do
    if [ ! -d "$d" ]; then
        echo "Non-existent source!"
        exit 1
    fi

    if [ $sync -eq 1 ]
    then
	echo "Syncing source \"$d\" to \"$TARGET\"." >&2
	btrfs-sync.sh "$d" "$TARGET"

	if [ $? -ne 0 ]; then
	    echo "\tError, continuing with next target." >&2
	    continue
	fi
    fi

    target_dir="$(echo ${TARGET}${d} | sed s:/$::g)"

    btrfs-snap -r "$target_dir" "$prefix" "$count"

    if [ $? -ne 0 ]; then
	echo "Error running btrfs-snap on \"$target_dir\"." >&2
    fi

    echo "******"
done
