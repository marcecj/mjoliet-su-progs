#!/bin/sh

arch="amd64"
stage3_variant="-amd64-systemd"
container_name="gentoo-amd64-systemd"
config_base_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gentoo_containers"

while getopts a:d:s:n: a
do
    case $a in
        a) arch="$OPTARG";;
        d) if [ ! -d "$OPTARG" ]; then echo >&2 "Error: path \"$OPTARG\" does not exist."; exit 1; fi
	config_base_dir="$OPTARG";;
        s) stage3_variant="-$OPTARG";;
        n) container_name="$OPTARG";;
        \?) exit 1;;
    esac
done

CONFIG_DIR="${config_base_dir}/${container_name}"
BASE_URL="http://distfiles.gentoo.org/releases/${arch}/autobuilds/"
LATEST="${BASE_URL}latest-stage3${stage3_variant}.txt"
STAGE3_URL="${BASE_URL}$(curl -s $LATEST | tail -n1 | cut -d' ' -f1)"

# create the initial container from the current stage3 image
machinectl pull-tar --verify=no "${STAGE3_URL}" "${container_name}"

# install an nspawn file if available
if [ -f "${CONFIG_DIR}/container.nspawn" ]
then
    install -m0644 \
        "${CONFIG_DIR}/container.nspawn" \
        "/etc/systemd/nspawn/${container_name}.nspawn"
fi

# systemd-nspawn will use a temporary source directory if $CONFIG_DIR is empty,
# so make sure it is if $CONFIG_DIR does not exist
[ -d "$CONFIG_DIR" ] || CONFIG_DIR=""

systemd-nspawn --user root -U -M "${container_name}" --bind-ro="${CONFIG_DIR}":/root/container.conf/ sh -s <<EOF

# install custom files into the file system
if [ -d /root/container.conf/filesystem ]
then
    printf "\n*** Copying files into the root file system.\n"
    rsync -r /root/container.conf/filesystem/ /
fi

# initialise and sync the portage tree
emerge-webrsync
emerge --sync

# run pre-installation setup
if [ -d /root/container.conf/scripts.preinst ]
then
    for f in /root/container.conf/scripts.preinst/*.sh
    do
        printf "\n*** Executing \"\${f}\" in container\n"
        . "\${f}"
    done
fi

# update the system
emerge @world -uDNv

# install desired packages
if [ -f /root/container.conf/packages ]
then
    emerge -v \$(cat /root/container.conf/packages)
fi

# run post-installation setup
if [ -d /root/container.conf/scripts.postinst ]
then
    for f in /root/container.conf/scripts.postinst/*.sh
    do
        printf "\n*** Executing \"\${f}\" in container\n"
        . "\${f}"
    done
fi
EOF
