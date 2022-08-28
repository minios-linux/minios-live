#!/bin/bash

TEST_DESCRIPTION="root filesystem on a btrfs filesystem with /usr subvolume"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break"

client_run() {
    local test_name="$1"; shift
    local client_opts="$*"

    echo "CLIENT TEST START: $test_name"

    dd if=/dev/zero of=$TESTDIR/result bs=1M count=1
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/root.btrfs \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/usr.btrfs \
        -drive format=raw,index=2,media=disk,file=$TESTDIR/result \
        -watchdog i6300esb -watchdog-action poweroff \
        -append "panic=1 systemd.crash_reboot root=LABEL=dracut $client_opts quiet rd.retry=3 rd.info console=ttyS0,115200n81 selinux=0 rd.debug rd.shell=0 $DEBUGFAIL" \
        -initrd $TESTDIR/initramfs.testing

    if ! grep -F -m 1 -q dracut-root-block-success $TESTDIR/result; then
        echo "CLIENT TEST END: $test_name [FAILED]"
        return 1
    fi
    echo "CLIENT TEST END: $test_name [OK]"

}

test_run() {
    client_run "no option specified" || return 1
    client_run "readonly root" "ro" || return 1
    client_run "writeable root" "rw" || return 1
    return 0
}

test_setup() {
    rm -f -- $TESTDIR/root.btrfs
    rm -f -- $TESTDIR/usr.btrfs
    # Create the blank file to use as a root filesystem
    dd if=/dev/null of=$TESTDIR/root.btrfs bs=1M seek=160
    dd if=/dev/null of=$TESTDIR/usr.btrfs bs=1M seek=160

    kernel=$KVERSION
    # Create what will eventually be our root filesystem onto an overlay
    (
        export initdir=$TESTDIR/overlay/source
        mkdir -p $initdir
        . $basedir/dracut-init.sh
        (
            cd "$initdir"
            mkdir -p -- dev sys proc etc var/run tmp
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            for i in bin sbin lib lib64; do
                ln -sfnr usr/$i $i
            done
        )
        inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
                      mount dmesg dhclient mkdir cp ping dhclient \
                      umount strace less setsid dd
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep
        inst_simple ./fstab /etc/fstab
        inst_simple /etc/os-release
        inst ./test-init.sh /sbin/init
        find_binary plymouth >/dev/null && inst_multiple plymouth
        cp -a /etc/ld.so.conf* $initdir/etc
        ldconfig -r "$initdir"
    )

    # second, install the files needed to make the root filesystem
    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple sfdisk mkfs.btrfs btrfs poweroff cp umount sync dd
        inst_hook initqueue 01 ./create-root.sh
        inst_hook initqueue/finished 01 ./finished-false.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    # create an initramfs that will create the target root filesystem.
    # We do it this way so that we do not risk trashing the host mdraid
    # devices, volume groups, encrypted partitions, etc.
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -m "dash udev-rules btrfs base rootfs-block fs-lib kernel-modules qemu" \
                       -d "piix ide-gd_mod ata_piix btrfs sd_mod" \
                       --nomdadmconf \
                       --nohardlink \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.makeroot $KVERSION || return 1

    # Invoke KVM and/or QEMU to actually create the target filesystem.

    #    echo $TESTDIR/overlay
    #    echo $TESTDIR/initramfs.makeroot
    #exit 1
    rm -rf -- $TESTDIR/overlay

    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/root.btrfs \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/usr.btrfs \
        -append "root=/dev/dracut/root rw rootfstype=btrfs quiet console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.makeroot  || return 1
    if ! grep -F -m 1 -q dracut-root-block-created $TESTDIR/root.btrfs; then
        echo "Could not create root filesystem"
        return 1
    fi

    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple poweroff shutdown dd
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
         -a "debug watchdog" \
         -o "network kernel-network-modules" \
         -d "piix ide-gd_mod ata_piix btrfs sd_mod i6300esb ib700wdt" \
         --no-hostonly-cmdline -N \
         -f $TESTDIR/initramfs.testing $KVERSION || return 1

    rm -rf -- $TESTDIR/overlay

    #       -o "plymouth network md dmraid multipath fips caps crypt btrfs resume dmsquash-live dm"
}

test_cleanup() {
    return 0
}

. $testdir/test-functions
