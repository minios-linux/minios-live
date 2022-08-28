#!/bin/bash
TEST_DESCRIPTION="root filesystem on an encrypted LVM PV on a degraded RAID-5"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break rd.debug"
#DEBUGFAIL="rd.shell rd.break=pre-mount udev.log-priority=debug"
#DEBUGFAIL="rd.shell rd.udev.log-priority=debug loglevel=70 systemd.log_target=kmsg"
#DEBUGFAIL="rd.shell loglevel=70 systemd.log_target=kmsg"

client_run() {
    echo "CLIENT TEST START: $@"
    cp --sparse=always --reflink=auto $TESTDIR/disk2.img $TESTDIR/disk2.img.new
    cp --sparse=always --reflink=auto $TESTDIR/disk3.img $TESTDIR/disk3.img.new

    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/marker.img \
        -drive format=raw,index=2,media=disk,file=$TESTDIR/disk2.img.new \
        -drive format=raw,index=3,media=disk,file=$TESTDIR/disk3.img.new \
        -append "panic=1 systemd.crash_reboot $* systemd.log_target=kmsg root=LABEL=root rw rd.retry=10 rd.info console=ttyS0,115200n81 log_buf_len=2M selinux=0 rd.shell=0 $DEBUGFAIL " \
        -initrd $TESTDIR/initramfs.testing
    if ! grep -F -m 1 -q dracut-root-block-success $TESTDIR/marker.img; then
        echo "CLIENT TEST END: $@ [FAIL]"
        return 1;
    fi
    rm -f -- $TESTDIR/marker.img
    dd if=/dev/null of=$TESTDIR/marker.img bs=1M seek=40

    echo "CLIENT TEST END: $@ [OK]"
    return 0
}

test_run() {
    read LUKS_UUID < $TESTDIR/luksuuid
    read MD_UUID < $TESTDIR/mduuid

    client_run failme && return 1
    client_run rd.auto || return 1


    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.md.conf=0 rd.lvm.vg=dracut || return 1

    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=failme rd.md.conf=0 rd.lvm.vg=dracut failme && return 1

    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm=0 failme && return 1
    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm=0 rd.auto=1 failme && return 1
    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm.vg=failme failme && return 1
    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm.vg=dracut || return 1
    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm.lv=dracut/failme failme && return 1
    client_run rd.luks.uuid=$LUKS_UUID rd.md.uuid=$MD_UUID rd.lvm.lv=dracut/root || return 1

    return 0
}

test_setup() {
    # Create the blank file to use as a root filesystem
    rm -f -- $TESTDIR/marker.img
    dd if=/dev/null of=$TESTDIR/marker.img bs=1M seek=40
    dd if=/dev/null of=$TESTDIR/disk1.img bs=1M seek=35
    dd if=/dev/null of=$TESTDIR/disk2.img bs=1M seek=35
    dd if=/dev/null of=$TESTDIR/disk3.img bs=1M seek=35

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
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep
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
        inst_multiple sfdisk mke2fs poweroff cp umount dd grep
        inst_hook initqueue 01 ./create-root.sh
        inst_hook initqueue/finished 01 ./finished-false.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    # create an initramfs that will create the target root filesystem.
    # We do it this way so that we do not risk trashing the host mdraid
    # devices, volume groups, encrypted partitions, etc.
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -m "dash crypt lvm mdraid udev-rules base rootfs-block fs-lib kernel-modules qemu" \
                       -d "piix ide-gd_mod ata_piix ext2 sd_mod" \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.makeroot $KVERSION || return 1
    rm -rf -- $TESTDIR/overlay
    # Invoke KVM and/or QEMU to actually create the target filesystem.
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/marker.img \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/disk1.img \
        -drive format=raw,index=2,media=disk,file=$TESTDIR/disk2.img \
        -drive format=raw,index=3,media=disk,file=$TESTDIR/disk3.img \
        -append "root=/dev/fakeroot rw rootfstype=ext2 quiet console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.makeroot  || return 1

    grep -F -m 1 -q dracut-root-block-created $TESTDIR/marker.img || return 1
    eval $(grep -F --binary-files=text -m 1 MD_UUID $TESTDIR/marker.img)
    eval $(grep -F -a -m 1 ID_FS_UUID $TESTDIR/marker.img)
    echo $ID_FS_UUID > $TESTDIR/luksuuid
    eval $(grep -F --binary-files=text -m 1 MD_UUID $TESTDIR/marker.img)
    echo "$MD_UUID" > $TESTDIR/mduuid

    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple poweroff shutdown dd
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
        inst ./cryptroot-ask.sh /sbin/cryptroot-ask
        mkdir -p $initdir/etc
        echo "ARRAY /dev/md0 level=raid5 num-devices=3 UUID=$MD_UUID" > $initdir/etc/mdadm.conf
        echo "luks-$ID_FS_UUID UUID=$ID_FS_UUID /etc/key" > $initdir/etc/crypttab
        echo -n test > $initdir/etc/key
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
