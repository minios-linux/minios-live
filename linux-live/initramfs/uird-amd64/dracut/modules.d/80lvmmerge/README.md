# lvmmerge - dracut module

## Preparation
- ensure that the lvm thin pool is big enough
- backup any (most likely /boot and /boot/efi) device with:
```
# mkdir /restoredev
# dev=<device>; umount $dev; dd if="$dev" of=/restoredev/$(systemd-escape -p "$dev"); mount $dev
```
- backup the MBR
```
# dev=<device>; dd if="$dev" of=/restoredev/$(systemd-escape -p "$dev") bs=446 count=1
# ls -l /dev/disk/by-path/virtio-pci-0000\:00\:07.0
lrwxrwxrwx. 1 root root 9 Jul 24 04:27 /dev/disk/by-path/virtio-pci-0000:00:07.0 -> ../../vda
```
- backup some partitions
```
# dev=/dev/disk/by-path/virtio-pci-0000:00:07.0
# dd if="$dev" of=/restoredev/$(systemd-escape -p "$dev") bs=446 count=1
# umount /boot/efi
# dev=/dev/disk/by-partuuid/687177a8-86b3-4e37-a328-91d20db9563c
# dd if="$dev" of=/restoredev/$(systemd-escape -p "$dev")
# umount /boot
# dev=/dev/disk/by-partuuid/4fdf99e9-4f28-4207-a26f-c76546824eaf
# dd if="$dev" of=/restoredev/$(systemd-escape -p "$dev")
```
Final /restoredev
```
# ls -al /restoredev/
total 1253380
drwx------.  2 root root        250 Jul 24 04:38 .
dr-xr-xr-x. 18 root root        242 Jul 24 04:32 ..
-rw-------. 1 root root  209715200 Jul 24 04:34 dev-disk-by\x2dpartuuid-4fdf99e9\x2d4f28\x2d4207\x2da26f\x2dc76546824eaf
-rw-------. 1 root root 1073741824 Jul 24 04:34 dev-disk-by\x2dpartuuid-687177a8\x2d86b3\x2d4e37\x2da328\x2d91d20db9563c
-rw-------. 1 root root        446 Jul 24 04:38 dev-disk-by\x2dpath-virtio\x2dpci\x2d0000:00:07.0
```
- make a thin snapshot
```
# lvm lvcreate -pr -s rhel/root --name reset
```

- mark the snapshot with a tag
```
# lvm lvchange --addtag reset rhel/reset
```

- remove /restoredev
```
# rm -fr /restoredev
```

## Operation

If a boot entry with ```rd.lvm.mergetags=<tag>``` is selected and there are LVs with ```<tag>```
dracut will
- make a copy of the snapshot
- merge it back to the original
- rename the copy back to the name of the snapshot
- if /restordev appears in the root, then it will restore the images
  found in that directory. This can be used to restore /boot and /boot/efi and the
  MBR of the boot device
