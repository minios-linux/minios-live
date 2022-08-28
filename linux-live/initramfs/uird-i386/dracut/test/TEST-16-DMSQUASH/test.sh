#!/bin/bash
TEST_DESCRIPTION="root filesystem on a LiveCD dmsquash filesystem"

KVERSION="${KVERSION-$(uname -r)}"

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break rd.debug systemd.log_level=debug systemd.log_target=console"

test_check() {
    for pdir in $(python -c "import site; print(site.getsitepackages())" | sed -e 's/\[\(.*\)\]/\1/' -e "s/', /' /g") ; do
        pdir1=$(echo $pdir | sed "s/^'\(.*\)'$/\1/")
        if [[ -d $pdir1/imgcreate ]]; then
            return 0
        fi
    done
    echo "python-imgcreate not installed"
    return 1
}

test_run() {
    "$testdir"/run-qemu \
              -boot order=d \
              -drive format=raw,bps=1000000,index=0,media=disk,file="$TESTDIR"/livecd.iso \
              -drive format=raw,index=1,media=disk,file="$TESTDIR"/root.img \
              -append "panic=1 systemd.crash_reboot root=live:CDLABEL=LiveCD live rw quiet rd.retry=3 rd.info console=ttyS0,115200n81 selinux=0 rd.shell=0 $DEBUGFAIL" \
              -initrd "$TESTDIR"/initramfs.testing

    # mediacheck test with qemu GUI
    # "$testdir"/run-qemu \
        #     -drive format=raw,bps=1000000,index=0,media=disk,file="$TESTDIR"/livecd.iso \
        #     -drive format=raw,index=1,media=disk,file="$TESTDIR"/root.img \
        #     -m 512M  -smp 2 \
        #     -net none \
        #     -append "root=live:CDLABEL=LiveCD live quiet rhgb selinux=0 rd.live.check" \
        #     -initrd "$TESTDIR"/initramfs.testing

    grep -F -m 1 -q dracut-root-block-success -- "$TESTDIR"/root.img || return 1
}

test_setup() {
    mkdir -p -- "$TESTDIR"/overlay
    (
        export initdir="$TESTDIR"/overlay
        . "$basedir"/dracut-init.sh
        inst_multiple poweroff shutdown
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
    )

    dd if=/dev/zero of="$TESTDIR"/root.img count=100

    $basedir/dracut.sh -l -i "$TESTDIR"/overlay / \
         -a "debug dmsquash-live qemu" \
         -o "rngd" \
         -d "piix ide-gd_mod ata_piix ext3 sd_mod" \
         --no-hostonly-cmdline -N \
         -f "$TESTDIR"/initramfs.testing "$KVERSION" || return 1

    mkdir -p -- "$TESTDIR"/root-source
    kernel="$KVERSION"
    # Create what will eventually be our root filesystem onto an overlay
    (
        export initdir="$TESTDIR"/root-source
        . "$basedir"/dracut-init.sh
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
                      umount strace less dd
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [[ -f ${_terminfodir}/l/linux ]] && break
        done
        inst_multiple -o "${_terminfodir}"/l/linux
        inst "$basedir/modules.d/35network-legacy/dhclient-script.sh" "/sbin/dhclient-script"
        inst "$basedir/modules.d/35network-legacy/ifup.sh" "/sbin/ifup"
        inst_multiple grep syslinux isohybrid
        for f in /usr/share/syslinux/*; do
            inst_simple "$f"
        done
        inst_simple /etc/os-release
        inst ./test-init.sh /sbin/init
        inst "$TESTDIR"/initramfs.testing "/boot/initramfs-$KVERSION.img"
        [[ -f /etc/machine-id ]] && read MACHINE_ID < /etc/machine-id

        VMLINUZ="/lib/modules/${KVERSION}/vmlinuz"
        if ! [[ -e $VMLINUZ ]]; then
            if [[ $MACHINE_ID ]] && ( [[ -d /boot/${MACHINE_ID} ]] || [[ -L /boot/${MACHINE_ID} ]] ); then
                VMLINUZ="/boot/${MACHINE_ID}/$KVERSION/linux"
            fi
        fi
        [[ -e $VMLINUZ ]] || VMLINUZ="/boot/vmlinuz-${KVERSION}"

        inst "$VMLINUZ" "/boot/vmlinuz-${KVERSION}"
        find_binary plymouth >/dev/null && inst_multiple plymouth
        cp -a -- /etc/ld.so.conf* "$initdir"/etc
        ldconfig -r "$initdir"
    )
    python create.py -d -c livecd-fedora-minimal.ks
    return 0
}

test_cleanup() {
    return 0
}

. "$testdir"/test-functions
