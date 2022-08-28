#!/bin/sh

trap 'poweroff -f' EXIT

# don't let udev and this script step on eachother's toes
for x in 61-dmraid-imsm.rules 64-md-raid.rules 65-md-incremental-imsm.rules 65-md-incremental.rules 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    rm -f -- "/etc/udev/rules.d/$x"
done
rm -f -- /etc/lvm/lvm.conf

udevadm control --reload
# dmraid does not want symlinks in --disk "..."
if [ -e /dev/hda ] ; then
    echo y|dmraid -f isw -C Test0 --type 1 --disk "/dev/hdb /dev/hdc"
else
    echo y|dmraid -f isw -C Test0 --type 1 --disk "/dev/sdb /dev/sdc"
fi
udevadm settle

SETS=$(dmraid -c -s)
# scan and activate all DM RAIDS
for s in $SETS; do
   dmraid -ay -i -p --rm_partitions "$s"
   [ -e "/dev/mapper/$s" ] && kpartx -a -p p "/dev/mapper/$s"
done

udevadm settle
sleep 1
udevadm settle

sfdisk -g /dev/mapper/isw*Test0
# save a partition at the beginning for future flagging purposes
sfdisk --no-reread /dev/mapper/isw*Test0 <<EOF
,4M
,28M
,28M
,28M
EOF

udevadm settle
dmraid -a n
udevadm settle

SETS=$(dmraid -c -s -i)
# scan and activate all DM RAIDS
for s in $SETS; do
   dmraid -ay -i -p --rm_partitions "$s"
   [ -e "/dev/mapper/$s" ] && kpartx -a -p p "/dev/mapper/$s"
done

udevadm settle

mdadm --create /dev/md0 --run --auto=yes --level=5 --raid-devices=3 \
	/dev/mapper/isw*p2 \
	/dev/mapper/isw*p3 \
	/dev/mapper/isw*p4

# wait for the array to finish initailizing, otherwise this sometimes fails
# randomly.
mdadm -W /dev/md0
set -e
lvm pvcreate -ff  -y /dev/md0
lvm vgcreate dracut /dev/md0
lvm lvcreate -l 100%FREE -n root dracut
lvm vgchange -ay
mke2fs -L root /dev/dracut/root
mkdir -p /sysroot
mount /dev/dracut/root /sysroot
cp -a -t /sysroot /source/*
umount /sysroot
lvm lvchange -a n /dev/dracut/root
udevadm settle
mdadm --detail --export /dev/md0 |grep -F MD_UUID > /tmp/mduuid
. /tmp/mduuid
echo "MD_UUID=$MD_UUID"
{ echo "dracut-root-block-created"; echo MD_UUID=$MD_UUID;} | dd oflag=direct,dsync of=/dev/sda
mdadm --wait-clean /dev/md0
