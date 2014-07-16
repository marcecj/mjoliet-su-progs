DIRS="/
/home
/home/marcec/VBoxDrives
/home/marcec/multimedia"
TARGET="/run/media/marcec/MARCEC_BACKUP/"

if [ ! -d "$TARGET" ];
then
    echo "Non-existent target!"
    exit
fi

echo "$DIRS" | while read d;
do
    if [ ! -d "$d" ]; then
        echo "Non-existent source!"
        exit 1
    fi

    ./btrfs-sync.sh "$d" "$TARGET"
    echo "******"

    if [ $? -ne 0 ]; then
	echo "Error syncing source \"$d\" to \"$TARGET\", continuing with next target." >&2
    fi
done
