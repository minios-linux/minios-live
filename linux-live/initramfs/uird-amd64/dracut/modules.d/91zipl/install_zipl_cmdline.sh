#!/bin/bash

DEV="$1"
MNT=/boot/zipl

if [ -z "$DEV" ] ; then
    echo "No IPL device given"
    > /tmp/install.zipl.cmdline-done
    exit 1
fi

[ -d ${MNT} ] || mkdir -p ${MNT}

mount -o ro ${DEV} ${MNT}
if [ "$?" != "0" ] ; then
    echo "Failed to mount ${MNT}"
    > /tmp/install.zipl.cmdline-done
    exit 1
fi

if [ -f ${MNT}/dracut-cmdline.conf ] ; then
    cp ${MNT}/dracut-cmdline.conf /etc/cmdline.d/99zipl.conf
fi

if [ -f ${MNT}/active_devices.txt ] ; then
    while read dev etc ; do
        [ "$dev" = "#" -o "$dev" = "" ] && continue;
        cio_ignore -r $dev
    done < ${MNT}/active_devices.txt
fi

umount ${MNT}

if [ -f /etc/cmdline.d/99zipl.conf ] ; then
    systemctl restart dracut-cmdline.service
    systemctl restart systemd-udev-trigger.service
fi
> /tmp/install.zipl.cmdline-done

exit 0
