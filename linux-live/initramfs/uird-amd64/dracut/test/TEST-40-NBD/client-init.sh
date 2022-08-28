#!/bin/sh
>/dev/watchdog
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
exec >/dev/console 2>&1
while read dev fs fstype opts rest || [ -n "$dev" ]; do
    [ "$dev" = "rootfs" ] && continue
    [ "$fs" != "/" ] && continue
    echo "nbd-OK $fstype $opts" | dd oflag=direct,dsync of=/dev/sda
    echo "nbd-OK $fstype $opts" 
    break
done < /proc/mounts
export TERM=linux
export PS1='nbdclient-test:\w\$ '
stty sane
echo "made it to the rootfs! Powering down."
#sh -i
>/dev/watchdog
mount -n -o remount,ro / &> /dev/null
>/dev/watchdog
poweroff -f
