#!/bin/sh
if [ -z $iscsi_lun ]; then
    iscsi_lun=0
fi
NEWROOT=${NEWROOT:-/sysroot}

for disk in /dev/disk/by-path/*-iscsi-*-$iscsi_lun; do
    if mount -t ${fstype:-auto} -o "$rflags" $disk $NEWROOT; then
        if [ ! -d $NEWROOT/proc ]; then
            umount $disk
            continue
        fi
        break
    fi
done
