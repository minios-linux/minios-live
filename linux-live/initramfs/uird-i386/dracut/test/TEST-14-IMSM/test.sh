#!/bin/bash
TEST_DESCRIPTION="root filesystem on LVM PV on a isw dmraid"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell"
#DEBUGFAIL="$DEBUGFAIL udev.log-priority=debug"

client_run() {
    echo "CLIENT TEST START: $@"

    rm -f -- $TESTDIR/marker.img
    dd if=/dev/null of=$TESTDIR/marker.img bs=1M seek=1

    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/marker.img \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/disk1 \
        -drive format=raw,index=2,media=disk,file=$TESTDIR/disk2 \
        -append "panic=1 systemd.crash_reboot $* root=LABEL=root rw debug rd.retry=5 rd.debug console=ttyS0,115200n81 selinux=0 rd.info rd.shell=0 $DEBUGFAIL" \
        -initrd $TESTDIR/initramfs.testing

    if ! grep -F -m 1 -q dracut-root-block-success $TESTDIR/marker.img; then
        echo "CLIENT TEST END: $@ [FAIL]"
        return 1;
    fi

    echo "CLIENT TEST END: $@ [OK]"
    return 0
}

test_run() {
    read MD_UUID < $TESTDIR/mduuid
    if [[ -z $MD_UUID ]]; then
        echo "Setup failed"
        return 1
    fi

    client_run rd.auto rd.md.imsm=0 || return 1
    client_run rd.md.uuid=$MD_UUID rd.dm=0 || return 1
    # This test succeeds, because the mirror parts are found without
    # assembling the mirror itsself, which is what we want
    client_run rd.md.uuid=$MD_UUID rd.md=0 rd.md.imsm failme && return 1
    client_run rd.md.uuid=$MD_UUID rd.md=0 failme && return 1
    # the following test hangs on newer md
    client_run rd.md.uuid=$MD_UUID rd.dm=0 rd.md.imsm rd.md.conf=0 || return 1
    return 0
}

test_setup() {

    # Create the blank file to use as a root filesystem
    rm -f -- $TESTDIR/marker.img
    rm -f -- $TESTDIR/disk1
    rm -f -- $TESTDIR/disk2
    dd if=/dev/null of=$TESTDIR/marker.img bs=1M seek=1
    dd if=/dev/null of=$TESTDIR/disk1 bs=1M seek=104
    dd if=/dev/null of=$TESTDIR/disk2 bs=1M seek=104

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
        )
        inst_multiple sh df free ls shutdown poweroff stty cat ps ln ip \
                      mount dmesg dhclient mkdir cp ping dhclient dd
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst_simple /etc/os-release
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep
        inst ./test-init.sh /sbin/init
        find_binary plymouth >/dev/null && inst_multiple plymouth
        cp -a /etc/ld.so.conf* $initdir/etc
        mkdir $initdir/run
        ldconfig -r "$initdir"
    )

    # second, install the files needed to make the root filesystem
    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple sfdisk mke2fs poweroff cp umount grep dd
        inst_hook initqueue 01 ./create-root.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    # create an initramfs that will create the target root filesystem.
    # We do it this way so that we do not risk trashing the host mdraid
    # devices, volume groups, encrypted partitions, etc.
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -m "dash lvm mdraid dmraid udev-rules base rootfs-block fs-lib kernel-modules qemu" \
                       -d "piix ide-gd_mod ata_piix ext2 sd_mod dm-multipath dm-crypt dm-round-robin faulty linear multipath raid0 raid10 raid1 raid456" \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.makeroot $KVERSION || return 1
    rm -rf -- $TESTDIR/overlay
    # Invoke KVM and/or QEMU to actually create the target filesystem.
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/marker.img \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/disk1 \
        -drive format=raw,index=2,media=disk,file=$TESTDIR/disk2 \
        -append "root=/dev/dracut/root rw rootfstype=ext2 quiet console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.makeroot  || return 1
    grep -F -m 1 -q dracut-root-block-created $TESTDIR/marker.img || return 1
    eval $(grep -F --binary-files=text -m 1 MD_UUID $TESTDIR/marker.img)

    if [[ -z $MD_UUID ]]; then
        echo "Setup failed"
        return 1
    fi

    echo $MD_UUID > $TESTDIR/mduuid
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
         -d "piix ide-gd_mod ata_piix ext2 sd_mod" \
         --no-hostonly-cmdline -N \
         -f $TESTDIR/initramfs.testing $KVERSION || return 1
}

test_cleanup() {
    return 0
}

. $testdir/test-functions
