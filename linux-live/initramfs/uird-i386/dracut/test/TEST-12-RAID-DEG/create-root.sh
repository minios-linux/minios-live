#!/bin/sh
# don't let udev and this script step on eachother's toes

trap 'poweroff -f' EXIT

for x in 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    > "/etc/udev/rules.d/$x"
done
rm -f -- /etc/lvm/lvm.conf
udevadm control --reload
udevadm settle
sleep 1
mdadm --create /dev/md0 --run --auto=yes --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
# wait for the array to finish initailizing, otherwise this sometimes fails
# randomly.
mdadm -W /dev/md0
printf test >keyfile
cryptsetup -q luksFormat /dev/md0 /keyfile
echo "The passphrase is test"
set -e
cryptsetup luksOpen /dev/md0 dracut_crypt_test </keyfile
lvm pvcreate -ff  -y /dev/mapper/dracut_crypt_test
lvm vgcreate dracut /dev/mapper/dracut_crypt_test
lvm lvcreate -l 100%FREE -n root dracut
lvm vgchange -ay
mke2fs -L root /dev/dracut/root
mkdir -p /sysroot
mount /dev/dracut/root /sysroot
cp -a -t /sysroot /source/*
mkdir /sysroot/run
umount /sysroot
lvm lvchange -a n /dev/dracut/root
udevadm settle
cryptsetup luksClose /dev/mapper/dracut_crypt_test
udevadm settle
mdadm -W /dev/md0 || :
udevadm settle
mdadm --detail --export /dev/md0 |grep -F MD_UUID > /tmp/mduuid
. /tmp/mduuid
udevadm settle
eval $(udevadm info --query=env --name=/dev/md0|while read line || [ -n "$line" ]; do [ "$line" != "${line#*ID_FS_UUID*}" ] && echo $line; done;)
{ echo "dracut-root-block-created"; echo MD_UUID=$MD_UUID;  echo "ID_FS_UUID=$ID_FS_UUID";} | dd oflag=direct,dsync of=/dev/sda
