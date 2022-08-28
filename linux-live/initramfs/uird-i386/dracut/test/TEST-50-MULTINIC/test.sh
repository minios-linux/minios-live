#!/bin/bash

if [[ $NM ]]; then
    USE_NETWORK="network-manager"
    OMIT_NETWORK="network-legacy"
else
    USE_NETWORK="network-legacy"
    OMIT_NETWORK="network-manager"
fi

TEST_DESCRIPTION="root filesystem on NFS with multiple nics with $USE_NETWORK"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
#DEBUGFAIL="rd.shell rd.break"
#SERIAL="tcp:127.0.0.1:9999"

run_server() {
    # Start server first
    echo "MULTINIC TEST SETUP: Starting DHCP/NFS server"

    fsck -a "$TESTDIR"/server.ext3 || return 1

    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file="$TESTDIR"/server.ext3 \
        -net socket,listen=127.0.0.1:12350 \
        -net nic,macaddr=52:54:01:12:34:56,model=e1000 \
        ${SERIAL:+-serial "$SERIAL"} \
        ${SERIAL:--serial file:"$TESTDIR"/server.log} \
        -watchdog i6300esb -watchdog-action poweroff \
        -append "panic=1 systemd.crash_reboot loglevel=7 root=/dev/sda rootfstype=ext3 rw console=ttyS0,115200n81 selinux=0" \
        -initrd "$TESTDIR"/initramfs.server \
        -pidfile "$TESTDIR"/server.pid -daemonize || return 1

    chmod 644 -- "$TESTDIR"/server.pid || return 1

    # Cleanup the terminal if we have one
    tty -s && stty sane

    if ! [[ $SERIAL ]]; then
        while : ; do
            grep Serving "$TESTDIR"/server.log && break
            echo "Waiting for the server to startup"
            sleep 1
        done
    else
        echo Sleeping 10 seconds to give the server a head start
        sleep 10
    fi
}

client_test() {
    local test_name="$1"
    local mac1="$2"
    local mac2="$3"
    local mac3="$4"
    local cmdline="$5"
    local check="$6"

    echo "CLIENT TEST START: $test_name"

    # Need this so kvm-qemu will boot (needs non-/dev/zero local disk)
    if ! dd if=/dev/zero of="$TESTDIR"/client.img bs=1M count=1; then
        echo "Unable to make client sda image" 1>&2
        return 1
    fi

    $testdir/run-qemu -drive format=raw,index=0,media=disk,file="$TESTDIR"/client.img \
                      -net socket,connect=127.0.0.1:12350 \
                      -net nic,macaddr=52:54:00:12:34:$mac1,model=e1000 \
                      -net nic,macaddr=52:54:00:12:34:$mac2,model=e1000 \
                      -net nic,macaddr=52:54:00:12:34:$mac3,model=e1000 \
                      -netdev hubport,id=n1,hubid=1 \
                      -netdev hubport,id=n2,hubid=2 \
                      -device e1000,netdev=n1,mac=52:54:00:12:34:98 \
                      -device e1000,netdev=n2,mac=52:54:00:12:34:99 \
                      -watchdog i6300esb -watchdog-action poweroff \
                      -append "quiet rd.net.timeout.dhcp=3 panic=1 systemd.crash_reboot rd.shell=0 $cmdline $DEBUGFAIL rd.retry=5 ro console=ttyS0,115200n81 selinux=0 init=/sbin/init rd.debug systemd.log_target=console" \
                      -initrd "$TESTDIR"/initramfs.testing

    { read OK; read IFACES; } < "$TESTDIR"/client.img

    if [[ "$OK" != "OK" ]]; then
        echo "CLIENT TEST END: $test_name [FAILED - BAD EXIT]"
        return 1
    fi

    for i in $check; do
        if [[ " $IFACES " != *\ $i\ * ]]; then
            echo "$i not in '$IFACES'"
            echo "CLIENT TEST END: $test_name [FAILED - BAD IF]"
            return 1
        fi
    done

    for i in $IFACES; do
        if [[ " $check " != *\ $i\ * ]]; then
            echo "$i in '$IFACES', but should not be"
            echo "CLIENT TEST END: $test_name [FAILED - BAD IF]"
            return 1
        fi
    done

    echo "CLIENT TEST END: $test_name [OK]"
    return 0
}


test_run() {
    if ! run_server; then
        echo "Failed to start server" 1>&2
        return 1
    fi
    test_client
    ret=$?
    kill_server
    return $ret
}

test_client() {
    # Mac Numbering Scheme
    # ...:00-02 receive IP adresses all others don't
    # ...:02 receives a dhcp root-path

    # PXE Style BOOTIF=
    client_test "MULTINIC root=nfs BOOTIF=" \
                00 01 02 \
                "root=nfs:192.168.50.1:/nfs/client BOOTIF=52-54-00-12-34-00" \
                "ens2" || return 1

    client_test "MULTINIC root=nfs BOOTIF= ip=ens4:dhcp" \
                00 01 02 \
                "root=nfs:192.168.50.1:/nfs/client BOOTIF=52-54-00-12-34-00 ip=ens3:dhcp" \
                "ens2 ens3" || return 1

    # PXE Style BOOTIF= with dhcp root-path
    client_test "MULTINIC root=dhcp BOOTIF=" \
                00 01 02 \
                "root=dhcp BOOTIF=52-54-00-12-34-02" \
                "ens4" || return 1

    # Multinic case, where only one nic works
    client_test "MULTINIC root=nfs ip=dhcp" \
                FF 00 FE \
                "root=nfs:192.168.50.1:/nfs/client ip=dhcp" \
                "ens3" || return 1

    # Require two interfaces
    client_test "MULTINIC root=nfs ip=ens3:dhcp ip=ens4:dhcp bootdev=ens3" \
                00 01 02 \
                "root=nfs:192.168.50.1:/nfs/client ip=ens3:dhcp ip=ens4:dhcp bootdev=ens3" \
                "ens3 ens4" || return 1

    # Require three interfaces with dhcp root-path
    client_test "MULTINIC root=dhcp ip=ens2:dhcp ip=ens3:dhcp ip=ens4:dhcp bootdev=ens4" \
                00 01 02 \
                "root=dhcp ip=ens2:dhcp ip=ens3:dhcp ip=ens4:dhcp bootdev=ens4" \
                "ens2 ens3 ens4" || return 1

    client_test "MULTINIC bonding" \
                00 01 02 \
                "root=nfs:192.168.50.1:/nfs/client ip=bond0:dhcp  bond=bond0:ens2,ens3,ens4:mode=balance-rr" \
                "bond0" || return 1

    # bridge, where only one interface is actually connected
    client_test "MULTINIC bridging" \
                00 01 02 \
                "root=nfs:192.168.50.1:/nfs/client ip=bridge0:dhcp  bridge=bridge0:ens2,ens6,ens7" \
                "bridge0" || return 1
    return 0
}

test_setup() {
    # Make server root
    dd if=/dev/null of="$TESTDIR"/server.ext3 bs=1M seek=120
    mke2fs -j -F -- "$TESTDIR"/server.ext3
    mkdir -- "$TESTDIR"/mnt
    mount -o loop -- "$TESTDIR"/server.ext3 "$TESTDIR"/mnt
    kernel=$KVERSION
    (
        export initdir="$TESTDIR"/mnt
        . "$basedir"/dracut-init.sh

        (
            cd "$initdir";
            mkdir -p -- dev sys proc run var/run etc tmp var/lib/{dhcpd,rpcbind}
            mkdir -p -- var/lib/nfs/{v4recovery,rpc_pipefs}
            chmod 777 -- var/lib/rpcbind var/lib/nfs
        )

        for _f in modules.builtin.bin modules.builtin; do
            [[ $srcmods/$_f ]] && break
        done || {
            dfatal "No modules.builtin.bin and modules.builtin found!"
            return 1
        }

        for _f in modules.builtin.bin modules.builtin modules.order; do
            [[ $srcmods/$_f ]] && inst_simple "$srcmods/$_f" "/lib/modules/$kernel/$_f"
        done

        inst_multiple sh ls shutdown poweroff stty cat ps ln ip \
                      dmesg mkdir cp ping exportfs \
                      modprobe rpc.nfsd rpc.mountd showmount tcpdump \
                      /etc/services sleep mount chmod
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f "${_terminfodir}"/l/linux ] && break
        done
        inst_multiple -o "${_terminfodir}"/l/linux
        type -P portmap >/dev/null && inst_multiple portmap
        type -P rpcbind >/dev/null && inst_multiple rpcbind
        [ -f /etc/netconfig ] && inst_multiple /etc/netconfig
        type -P dhcpd >/dev/null && inst_multiple dhcpd
        [ -x /usr/sbin/dhcpd3 ] && inst /usr/sbin/dhcpd3 /usr/sbin/dhcpd
        instmods nfsd sunrpc ipv6 lockd af_packet
        inst_simple /etc/os-release
        inst ./server-init.sh /sbin/init
        inst ./hosts /etc/hosts
        inst ./exports /etc/exports
        inst ./dhcpd.conf /etc/dhcpd.conf
        inst_multiple /etc/nsswitch.conf /etc/rpc /etc/protocols

        inst_multiple rpc.idmapd /etc/idmapd.conf

        inst_libdir_file 'libnfsidmap_nsswitch.so*'
        inst_libdir_file 'libnfsidmap/*.so*'
        inst_libdir_file 'libnfsidmap*.so*'

        _nsslibs=$(sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' /etc/nsswitch.conf \
                       |  tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|')
        _nsslibs=${_nsslibs#|}
        _nsslibs=${_nsslibs%|}

        inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

        inst /etc/nsswitch.conf /etc/nsswitch.conf
        inst /etc/passwd /etc/passwd
        inst /etc/group /etc/group

        cp -a -- /etc/ld.so.conf* "$initdir"/etc
        ldconfig -r "$initdir"
        dracut_kernel_post
    )

    # Make client root inside server root
    (
        export initdir="$TESTDIR"/mnt/nfs/client
        . "$basedir"/dracut-init.sh
        (
            cd "$initdir"
            mkdir -p dev sys proc etc run
            mkdir -p var/lib/nfs/rpc_pipefs
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            for i in bin sbin lib lib64; do
                ln -sfnr usr/$i $i
            done
        )
        inst_multiple sh shutdown poweroff stty cat ps ln ip \
                      mount dmesg mkdir cp ping grep ls dd
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [[ -f ${_terminfodir}/l/linux ]] && break
        done
        inst_multiple -o "${_terminfodir}"/l/linux
        inst_simple /etc/os-release
        inst ./client-init.sh /sbin/init
        inst /etc/nsswitch.conf /etc/nsswitch.conf
        inst /etc/passwd /etc/passwd
        inst /etc/group /etc/group

        inst_multiple rpc.idmapd /etc/idmapd.conf
        inst_libdir_file 'libnfsidmap_nsswitch.so*'
        inst_libdir_file 'libnfsidmap/*.so*'
        inst_libdir_file 'libnfsidmap*.so*'

        _nsslibs=$(sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' -- /etc/nsswitch.conf \
                       |  tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|')
        _nsslibs=${_nsslibs#|}
        _nsslibs=${_nsslibs%|}

        inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

        cp -a -- /etc/ld.so.conf* "$initdir"/etc
        ldconfig -r "$initdir"
    )

    umount "$TESTDIR"/mnt
    rm -fr -- "$TESTDIR"/mnt

    # Make an overlay with needed tools for the test harness
    (
        export initdir="$TESTDIR"/overlay
        . "$basedir"/dracut-init.sh
        inst_multiple poweroff shutdown
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
        inst_simple ./99-default.link /etc/systemd/network/99-default.link
    )

    # Make server's dracut image
    $basedir/dracut.sh \
        -l -i "$TESTDIR"/overlay / \
        -m "dash udev-rules base rootfs-block fs-lib debug kernel-modules watchdog qemu" \
        -d "af_packet piix ide-gd_mod ata_piix ext3 sd_mod nfsv2 nfsv3 nfsv4 nfs_acl nfs_layout_nfsv41_files nfsd e1000 i6300esb ib700wdt" \
        --no-hostonly-cmdline -N \
        -f "$TESTDIR"/initramfs.server "$KVERSION" || return 1

    # Make client's dracut image
    $basedir/dracut.sh \
        -l -i "$TESTDIR"/overlay / \
        -o "plymouth ${OMIT_NETWORK}" \
        -a "debug ${USE_NETWORK}" \
        -d "af_packet piix sd_mod sr_mod ata_piix ide-gd_mod e1000 nfsv2 nfsv3 nfsv4 nfs_acl nfs_layout_nfsv41_files sunrpc i6300esb ib700wdt" \
        --no-hostonly-cmdline -N \
        -f "$TESTDIR"/initramfs.testing "$KVERSION" || return 1
}

kill_server() {
    if [[ -s "$TESTDIR"/server.pid ]]; then
        kill -TERM -- $(cat "$TESTDIR"/server.pid)
        rm -f -- "$TESTDIR"/server.pid
    fi
}

test_cleanup() {
    kill_server
}

. "$testdir"/test-functions
