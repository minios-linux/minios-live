#!/bin/sh
# MiniOS shutdown hook for dracut. It's automatically started by
# systemd (if you use it) on shutdown, no need for any tweaks.
# Purpose of this script is to unmount everything cleanly.
#
# Author: Tomas M <http://www.linux-live.org/>
# Author: crims0n <crims0n@minios.dev>

LIVEKITNAME="minios"
BEXT="sb"

# Dracut provides its own logging functions
type info >/dev/null 2>&1 || . /lib/dracut-lib.sh

info "Entering shutdown procedures"

detach_free_loops() {
    losetup -a | cut -d : -f 1 | xargs -r -n 1 losetup -d
}

# $1=dir
umount_all() {
    tac /proc/mounts | cut -d " " -f 2 | grep ^$1 | while read LINE; do
        umount $LINE 2>/dev/null
        detach_free_loops
    done
}

# Update devs so we are aware of all active /dev/loop* files.
# Detach loop devices which are no longer used
info "Detaching loops"
detach_free_loops

# do it the dirty way, simply try to umount everything to get rid of most mounts
info "Unmounting union"
umount_all /oldroot

# If oldroot is still mounted, there is something blocking.
# Lets move it somewhere so we can unmount it cleanly
info "Moving mounts outside of union if necessary"
NR=100
tac /proc/mounts | cut -d " " -f 2 | grep ^/oldroot/. | while read LINE; do
    NR=$(($NR + 1))
    mkdir -p /move/$NR
    mount --move $LINE /move/$NR 2>/dev/null
    umount /oldroot 2>/dev/null
done

# remember from which device we are started, so we can eject it later
# For dracut, check /lib/live/mount/medium instead of /memory/data
DEVICE="$(cat /proc/mounts | grep /lib/live/mount/medium | grep /dev/ | cut -d " " -f 1)"

info "going through several cycles of umounts to clear everything left"
for i in 1 2 3 4; do
    for d in $(ls -1 /move 2>/dev/null | sort); do
        umount_all /move/$d
    done
done

# For dracut, unmount /lib/live/mount instead of /memory
umount_all /lib/live/mount

# eject cdrom device if we were running from it
if [ -n "$DEVICE" ]; then
    for i in $(cat /proc/sys/dev/cdrom/info 2>/dev/null | grep name); do
        if [ "$DEVICE" = "/dev/$i" ]; then
            info "Attempting to eject /dev/$i..."
            eject /dev/$i
            info "CD/DVD tray will close in 6 seconds..."
            sleep 6
            eject -t /dev/$i
        fi
    done
fi

info "Shutdown cleanup complete"

exit 0
