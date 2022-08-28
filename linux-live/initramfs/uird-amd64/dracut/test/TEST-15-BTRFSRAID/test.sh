#!/bin/bash
TEST_DESCRIPTION="root filesystem on multiple device btrfs"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell"
test_run() {
    DISKIMAGE=$TESTDIR/TEST-15-BTRFSRAID-root.img
    MARKER_DISKIMAGE=$TESTDIR/TEST-15-BTRFSRAID-marker.img
    dd if=/dev/zero of=$MARKER_DISKIMAGE bs=512 count=10
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$MARKER_DISKIMAGE \
        -drive format=raw,index=1,media=disk,file=$DISKIMAGE \
        -append "panic=1 systemd.crash_reboot root=LABEL=root rw rd.retry=3 rd.info console=ttyS0,115200n81 selinux=0 rd.shell=0 $DEBUGFAIL" \
        -initrd $TESTDIR/initramfs.testing
    grep -F -m 1 -q dracut-root-block-success $MARKER_DISKIMAGE || return 1
}

test_setup() {
    # Create the blank file to use as a root filesystem
    DISKIMAGE=$TESTDIR/TEST-15-BTRFSRAID-root.img
    rm -f -- $DISKIMAGE
    dd if=/dev/null of=$DISKIMAGE bs=1M seek=1024

    kernel=$KVERSION
    # Create what will eventually be our root filesystem onto an overlay
    (
        export initdir=$TESTDIR/overlay/source
        . $basedir/dracut-init.sh
        (
            cd "$initdir"
            mkdir -p -- dev sys proc etc var/run tmp
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            for i in bin sbin lib lib64; do
                ln -sfnr usr/$i $i
            done
            mkdir -p -- var/lib/nfs/rpc_pipefs
        )
        inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
                      mount dmesg dhclient mkdir cp ping dhclient sync dd
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep
        inst ./test-init.sh /sbin/init
        inst_simple /etc/os-release
        find_binary plymouth >/dev/null && inst_multiple plymouth
        cp -a /etc/ld.so.conf* $initdir/etc
        ldconfig -r "$initdir"
    )

    # second, install the files needed to make the root filesystem
    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple sfdisk mkfs.btrfs poweroff cp umount dd
        inst_hook initqueue 01 ./create-root.sh
        inst_hook initqueue/finished 01 ./finished-false.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    # create an initramfs that will create the target root filesystem.
    # We do it this way so that we do not risk trashing the host mdraid
    # devices, volume groups, encrypted partitions, etc.
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -m "dash btrfs udev-rules base rootfs-block fs-lib kernel-modules qemu" \
                       -d "piix ide-gd_mod ata_piix btrfs sd_mod" \
                       --nomdadmconf \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.makeroot $KVERSION || return 1

    rm -rf -- $TESTDIR/overlay

    # Invoke KVM and/or QEMU to actually create the target filesystem.
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$DISKIMAGE \
        -append "root=/dev/fakeroot rw quiet console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.makeroot  || return 1

    dd if=$DISKIMAGE bs=512 count=4 skip=2048 | grep -F -m 1 -q dracut-root-block-created || return 1

    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple poweroff shutdown
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
         -o "plymouth network kernel-network-modules" \
         -a "debug" \
         -d "piix ide-gd_mod ata_piix btrfs sd_mod" \
         --no-hostonly-cmdline -N \
         -f $TESTDIR/initramfs.testing $KVERSION || return 1
}

test_cleanup() {
    return 0
}

. $testdir/test-functions
