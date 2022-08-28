#!/bin/sh

echo 'Generating "/run/initramfs/rdsosreport.txt"'

[ -d /run/initramfs ] || mkdir -p /run/initramfs

exec >/run/initramfs/rdsosreport.txt 2>&1

PWFILTER='s/\(ftp:\/\/.*\):.*@/\1:*******@/g;s/\(cifs:\/\/.*\):.*@/\1:*******@/g;s/cifspass=[^ ]*/cifspass=*******/g;s/iscsi:.*@/iscsi:******@/g;s/rd.iscsi.password=[^ ]*/rd.iscsi.password=******/g;s/rd.iscsi.in.password=[^ ]*/rd.iscsi.in.password=******/g'
set -x
cat /lib/dracut/dracut-*

cat /proc/cmdline | sed -e "$PWFILTER"

[ -f /etc/cmdline ] && cat /etc/cmdline | sed -e "$PWFILTER"

for _i in /etc/cmdline.d/*.conf; do
    [ -f "$_i" ] || break
    echo $_i
    cat $_i | sed -e "$PWFILTER"
done

cat /proc/self/mountinfo
cat /proc/mounts

blkid
blkid -o udev

ls -l /dev/disk/by*

for _i in /etc/conf.d/*.conf; do
    [ -f "$_i" ] || break
    echo $_i
    cat $_i | sed -e "$PWFILTER"
done

if command -v lvm >/dev/null 2>/dev/null; then
    lvm pvdisplay
    lvm vgdisplay
    lvm lvdisplay
fi

command -v dmsetup >/dev/null 2>/dev/null && dmsetup ls --tree

cat /proc/mdstat

command -v ip >/dev/null 2>/dev/null && ip addr

if command -v journalctl >/dev/null 2>/dev/null; then
    journalctl -ab --no-pager -o short-monotonic | sed -e "$PWFILTER"
else
    dmesg | sed -e "$PWFILTER"
    [ -f /run/initramfs/init.log ] && cat /run/initramfs/init.log | sed -e "$PWFILTER"
fi

