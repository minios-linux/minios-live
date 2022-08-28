#!/bin/sh
#
# Licensed under the GPLv2
#
# Copyright 2008-2012, Red Hat, Inc.
# Harald Hoyer <harald@redhat.com>

if [ ! -e /sys/module/block/parameters/events_dfl_poll_msecs ]; then
    # if the kernel does not support autopolling
    # then we have to do a
    # dirty hack for some cdrom drives,
    # which report no medium for quiet
    # some time.
    for cdrom in /sys/block/sr*; do
        [ -e "$cdrom" ] || continue
        # skip, if cdrom medium was already found
        strstr "$(udevadm info --query=env --path=${cdrom##/sys})" \
            ID_CDROM_MEDIA && continue
        echo change > "$cdrom/uevent"
    done
fi
