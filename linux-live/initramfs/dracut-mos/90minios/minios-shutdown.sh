#!/bin/sh
# MiniOS shutdown hook for dracut. It's automatically started by
# systemd (if you use it) on shutdown, no need for any tweaks.
# Purpose of this script is to unmount everything cleanly.
#
# Author: Tomas M <http://www.linux-live.org/>
# Author: crims0n <crims0n@minios.dev>

# Prevent multiple runs - this script should only run once
if [ -f /run/minios-shutdown-done ]; then
    exit 0
fi

LIVEKITNAME="minios"
BEXT="sb"

# Dracut provides its own logging functions
type info >/dev/null 2>&1 || . /lib/dracut-lib.sh

info "Entering MiniOS shutdown procedures"

detach_free_loops() {
    losetup -a | cut -d : -f 1 | xargs -r -n 1 losetup -d
}

# $1=dir
umount_all() {
    tac /proc/mounts | cut -d " " -f 2 | grep ^$1 | while read LINE; do
        umount $LINE 2>/dev/null || umount -l $LINE 2>/dev/null
        detach_free_loops
    done
}

# Update devs so we are aware of all active /dev/loop* files.
# Detach loop devices which are no longer used
info "Detaching loops"
detach_free_loops

# do it the dirty way, simply try to umount everything to get rid of most mounts
info "Unmounting union"

# First, try to kill any processes that might be using these mounts
if command -v fuser >/dev/null 2>&1; then
    fuser -km /oldroot 2>/dev/null || true
    sleep 1
fi

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
# In shutdown initramfs, the old root is at /oldroot
DEVICE="$(cat /proc/mounts | grep -E '(^/oldroot)?/lib/live/mount/medium' | grep /dev/ | cut -d " " -f 1 | head -1)"

info "going through several cycles of umounts to clear everything left"
for i in 1 2 3 4; do
    for d in $(ls -1 /move 2>/dev/null | sort); do
        umount_all /move/$d
    done
done

# Try to unmount both /lib/live/mount and /oldroot/lib/live/mount
# depending on whether we're in shutdown initramfs or not
umount_all /oldroot/lib/live/mount
umount_all /lib/live/mount

# Force unmount any remaining live mount points
for mp in /oldroot/lib/live/mount/medium /lib/live/mount/medium \
    /oldroot/lib/live/mount/changes /lib/live/mount/changes \
    /oldroot/lib/live/mount/bundles /lib/live/mount/bundles; do
    if grep -q " $mp " /proc/mounts 2>/dev/null; then
        umount -f $mp 2>/dev/null || umount -l $mp 2>/dev/null || true
    fi
done

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

# Mark that we've completed our work
touch /run/minios-shutdown-done

exit 0
