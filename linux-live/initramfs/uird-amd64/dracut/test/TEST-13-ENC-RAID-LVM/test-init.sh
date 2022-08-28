#!/bin/sh
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
exec >/dev/console 2>&1
echo "dracut-root-block-success" | dd oflag=direct,dsync of=/dev/sdb
export TERM=linux
export PS1='initramfs-test:\w\$ '
[ -f /etc/fstab ] || ln -s /proc/mounts /etc/fstab
stty sane
echo "made it to the rootfs! Powering down."
mount -n -o remount,ro /
poweroff -f
