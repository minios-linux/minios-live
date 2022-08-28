#!/bin/sh
# don't let udev and this script step on eachother's toes
for x in 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    > "/etc/udev/rules.d/$x"
done
rm -f -- /etc/lvm/lvm.conf
udevadm control --reload
# save a partition at the beginning for future flagging purposes
sfdisk /dev/sda <<EOF
,2M
,20M
,20M
,20M
EOF
udevadm settle
for i in sda2 sda3 sda4; do
lvm pvcreate -ff  -y /dev/$i ;
done && \
lvm vgcreate dracut /dev/sda[234] && \
lvm lvcreate -l 100%FREE -n root dracut && \
lvm vgchange -ay && \
mke2fs /dev/dracut/root && \
mkdir -p /sysroot && \
mount /dev/dracut/root /sysroot && \
cp -a -t /sysroot /source/* && \
umount /sysroot && \
sleep 1 && \
lvm lvchange -a n /dev/dracut/root && \
sleep 1 && \
echo "dracut-root-block-created" | dd oflag=direct,dsync of=/dev/sda1
poweroff -f
