#!/bin/sh
# don't let udev and this script step on eachother's toes
for x in 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    > "/etc/udev/rules.d/$x"
done
modprobe btrfs
udevadm control --reload
# save a partition at the beginning for future flagging purposes
sfdisk -X gpt /dev/sda <<EOF
,10M
,200M
,200M
,200M
,200M
EOF
udevadm settle
mkfs.btrfs -draid10 -mraid10 -L root /dev/sda2 /dev/sda3 /dev/sda4 /dev/sda5
udevadm settle
btrfs device scan
udevadm settle
set -e
mkdir -p /sysroot
mount -t btrfs /dev/sda5 /sysroot
cp -a -t /sysroot /source/*
umount /sysroot
echo "dracut-root-block-created" | dd oflag=direct,dsync of=/dev/sda1
poweroff -f
