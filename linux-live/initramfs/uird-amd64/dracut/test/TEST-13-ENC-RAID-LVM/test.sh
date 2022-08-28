#!/bin/bash
TEST_DESCRIPTION="root filesystem on LVM on encrypted partitions of a RAID-5"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break" # udev.log-priority=debug
#DEBUGFAIL="rd.shell rd.udev.log-priority=debug loglevel=70 systemd.log_target=kmsg systemd.log_target=debug"
#DEBUGFAIL="rd.shell loglevel=70 systemd.log_target=kmsg systemd.log_target=debug"

test_run() {
    LUKSARGS=$(cat $TESTDIR/luks.txt)

    dd if=/dev/zero of=$TESTDIR/check-success.img bs=1M count=1

    echo "CLIENT TEST START: $LUKSARGS"
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/root.ext2 \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/check-success.img \
        -append "panic=1 systemd.crash_reboot root=/dev/dracut/root rw rd.auto rd.retry=20 console=ttyS0,115200n81 selinux=0 rd.debug rootwait $LUKSARGS rd.shell=0 $DEBUGFAIL" \
        -initrd $TESTDIR/initramfs.testing
    grep -F -m 1 -q dracut-root-block-success $TESTDIR/check-success.img || return 1
    echo "CLIENT TEST END: [OK]"

    dd if=/dev/zero of=$TESTDIR/check-success.img bs=1M count=1

    echo "CLIENT TEST START: Any LUKS"
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/root.ext2 \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/check-success.img \
        -append "panic=1 systemd.crash_reboot root=/dev/dracut/root rw quiet rd.auto rd.retry=20 rd.info console=ttyS0,115200n81 selinux=0 rd.debug  $DEBUGFAIL" \
        -initrd $TESTDIR/initramfs.testing
    grep -F -m 1 -q dracut-root-block-success $TESTDIR/check-success.img || return 1
    echo "CLIENT TEST END: [OK]"

    dd if=/dev/zero of=$TESTDIR/check-success.img bs=1M count=1

    echo "CLIENT TEST START: Wrong LUKS UUID"
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/root.ext2 \
        -drive format=raw,index=1,media=disk,file=$TESTDIR/check-success.img \
        -append "panic=1 systemd.crash_reboot root=/dev/dracut/root rw quiet rd.auto rd.retry=10 rd.info console=ttyS0,115200n81 selinux=0 rd.debug  $DEBUGFAIL rd.luks.uuid=failme" \
        -initrd $TESTDIR/initramfs.testing
    grep -F -m 1 -q dracut-root-block-success $TESTDIR/check-success.img && return 1
    echo "CLIENT TEST END: [OK]"

    return 0
}

test_setup() {
    # Create the blank file to use as a root filesystem
    rm -f -- $TESTDIR/root.ext2
    dd if=/dev/null of=$TESTDIR/root.ext2 bs=1M seek=134

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
        inst_multiple sfdisk mke2fs poweroff cp umount grep dd
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
    $testdir/run-qemu -drive format=raw,index=0,media=disk,file=$TESTDIR/root.ext2 \
                      -append "root=/dev/fakeroot rw rootfstype=ext2 quiet console=ttyS0,115200n81 selinux=0" \
                      -initrd $TESTDIR/initramfs.makeroot  || return 1
    grep -F -m 1 -q dracut-root-block-created $TESTDIR/root.ext2 || return 1
    cryptoUUIDS=$(grep -F --binary-files=text  -m 3 ID_FS_UUID $TESTDIR/root.ext2)
    for uuid in $cryptoUUIDS; do
        eval $uuid
        printf ' rd.luks.uuid=luks-%s ' $ID_FS_UUID
    done > $TESTDIR/luks.txt


    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        inst_multiple poweroff shutdown dd
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
        inst ./cryptroot-ask.sh /sbin/cryptroot-ask
        mkdir -p $initdir/etc
        i=2
        for uuid in $cryptoUUIDS; do
            eval $uuid
            printf 'luks-%s /dev/sda%s /etc/key timeout=0\n' $ID_FS_UUID $i
            ((i+=1))
        done > $initdir/etc/crypttab
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
