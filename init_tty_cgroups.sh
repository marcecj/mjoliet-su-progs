#!/bin/sh
# CGROUPDIR=/sys/fs/cgroup
CGROUPDIR=/dev/cgroup
[ -d $CGROUPDIR ]          || mkdir $CGROUPDIR
[ -d $CGROUPDIR/cpu ]      || mkdir $CGROUPDIR/cpu 
mount -t cgroup cgroup $CGROUPDIR/cpu -o cpu
[ -d $CGROUPDIR/cpu/user ] || mkdir -m 0777 $CGROUPDIR/cpu/user
