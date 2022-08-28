#!/bin/bash

set -e

# do some sanity checks first
[ -e /run/initramfs/bin/sh ] && exit 0
[ -e /run/initramfs/.need_shutdown ] || exit 0

KERNEL_VERSION="$(uname -r)"

[[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut
SKIP="$dracutbasedir/skipcpio"
[[ -x $SKIP ]] || SKIP=cat

[[ -f /etc/machine-id ]] && read MACHINE_ID < /etc/machine-id

mount -o ro /boot &>/dev/null || true

if [[ $MACHINE_ID ]] && [[ -d /boot/${MACHINE_ID} || -L /boot/${MACHINE_ID} ]] ; then
    IMG="/boot/${MACHINE_ID}/${KERNEL_VERSION}/initrd"
fi
[[ -f $IMG ]] || IMG="/boot/initramfs-${KERNEL_VERSION}.img"

cd /run/initramfs

[ -f .need_shutdown -a -f "$IMG" ] || exit 1

if $SKIP "$IMG" | zcat | cpio -id --no-absolute-filenames --quiet >/dev/null; then
    rm -f -- .need_shutdown
elif $SKIP "$IMG" | xzcat | cpio -id --no-absolute-filenames --quiet >/dev/null; then
    rm -f -- .need_shutdown
elif $SKIP "$IMG" | lz4 -d -c | cpio -id --no-absolute-filenames --quiet >/dev/null; then
    rm -f -- .need_shutdown
elif $SKIP "$IMG" | zstd -d -c | cpio -id --no-absolute-filenames --quiet >/dev/null; then
    rm -f -- .need_shutdown
else
    # something failed, so we clean up
    echo "Unpacking of $IMG to /run/initramfs failed" >&2
    rm -f -- /run/initramfs/shutdown
    exit 1
fi

if [[ -d squash ]]; then
    unsquashfs -no-xattrs -f -d . squash/root.img >/dev/null
    if [ $? -ne 0 ]; then
        echo "Squash module is enabled for this initramfs but failed to unpack squash/root.img" >&2
        rm -f -- /run/initramfs/shutdown
        exit 1
    fi
fi

if [ -e /etc/selinux/config -a -x /usr/sbin/setfiles ] ; then
    . /etc/selinux/config
    /usr/sbin/setfiles -v -r /run/initramfs /etc/selinux/${SELINUXTYPE}/contexts/files/file_contexts /run/initramfs > /dev/null
fi

exit 0
