#!/bin/sh
PATH=/bin:/sbin

SQUASH_IMG=/squash/root.img
SQUASH_MNT=/squash/root
SQUASH_MNT_REC=/squash/mounts
SQUASHED_MNT="usr etc"

echo $SQUASH_MNT > $SQUASH_MNT_REC

# Following mount points are neccessary for mounting a squash image

[ ! -d /proc/self ] && \
    mount -t proc -o nosuid,noexec,nodev proc /proc

[ ! -d /sys/kernel ] && \
    mount -t sysfs -o nosuid,noexec,nodev sysfs /sys

[ ! -e /dev/loop-control ] && \
    mount -t devtmpfs -o mode=0755,noexec,nosuid,strictatime devtmpfs /dev

# Need a loop device backend, overlayfs, and squashfs module
modprobe loop
if [ $? != 0 ]; then
    echo "Unable to setup loop module"
fi

modprobe squashfs
if [ $? != 0 ]; then
    echo "Unable to setup squashfs module"
fi

modprobe overlay
if [ $? != 0 ]; then
    echo "Unable to setup overlay module"
fi

[ ! -d "$SQUASH_MNT" ] && \
	mkdir -m 0755 -p $SQUASH_MNT

# Mount the squashfs image
mount -t squashfs -o ro,loop $SQUASH_IMG $SQUASH_MNT

if [ $? != 0 ]; then
    echo "Unable to mount squashed initramfs image"
fi

for file in $SQUASHED_MNT; do
	lowerdir=$SQUASH_MNT/$file
	workdir=/squash/overlay-work/$file
	upperdir=/$file
	mntdir=/$file

	mkdir -m 0755 -p $workdir
	mkdir -m 0755 -p $mntdir

	mount -t overlay overlay -o\
		lowerdir=$lowerdir,upperdir=$upperdir,workdir=$workdir $mntdir

	echo $mntdir >> $SQUASH_MNT_REC
done
