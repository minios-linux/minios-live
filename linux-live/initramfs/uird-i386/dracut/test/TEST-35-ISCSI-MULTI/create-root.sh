#!/bin/sh
# don't let udev and this script step on eachother's toes
for x in 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    > "/etc/udev/rules.d/$x"
done
rm -f -- /etc/lvm/lvm.conf
udevadm control --reload
mkfs.ext3 -j -L singleroot -F /dev/sda && \
mkdir -p /sysroot && \
mount /dev/sda /sysroot && \
cp -a -t /sysroot /source/* && \
umount /sysroot && \
mdadm --create /dev/md0 --run --auto=yes --level=stripe --raid-devices=2 /dev/sdc /dev/sdd && \
mdadm -W /dev/md0 || : && \
lvm pvcreate -ff  -y /dev/md0 && \
lvm vgcreate dracut /dev/md0 && \
lvm lvcreate -l 100%FREE -n root dracut && \
lvm vgchange -ay && \
mkfs.ext3 -j -L sysroot /dev/dracut/root && \
mount /dev/dracut/root /sysroot && \
cp -a -t /sysroot /source/* && \
umount /sysroot && \
lvm lvchange -a n /dev/dracut/root && \
echo "dracut-root-block-created" | dd oflag=direct,dsync of=/dev/sdb
poweroff -f
