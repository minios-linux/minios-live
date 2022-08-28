#!/bin/bash

if [[ $NM ]]; then
    USE_NETWORK="network-manager"
    OMIT_NETWORK="network-legacy"
else
    USE_NETWORK="network-legacy"
    OMIT_NETWORK="network-manager"
fi

TEST_DESCRIPTION="root filesystem on NFS with $USE_NETWORK"

KVERSION=${KVERSION-$(uname -r)}

# Uncomment this to debug failures
DEBUGFAIL="loglevel=1"
#DEBUGFAIL="rd.shell rd.break rd.debug loglevel=7 "
#DEBUGFAIL="rd.debug loglevel=7 "
#SERVER_DEBUG="rd.debug loglevel=7"
#SERIAL="tcp:127.0.0.1:9999"

run_server() {
    # Start server first
    echo "NFS TEST SETUP: Starting DHCP/NFS server"

    fsck -a $TESTDIR/server.ext3 || return 1
    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/server.ext3 \
        -net socket,listen=127.0.0.1:12320 \
        -net nic,macaddr=52:54:00:12:34:56,model=e1000 \
        ${SERIAL:+-serial "$SERIAL"} \
        ${SERIAL:--serial file:"$TESTDIR"/server.log} \
        -watchdog i6300esb -watchdog-action poweroff \
        -append "panic=1 quiet root=/dev/sda rootfstype=ext3 rw console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.server \
        -pidfile $TESTDIR/server.pid -daemonize || return 1
    chmod 644 $TESTDIR/server.pid || return 1

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
    local mac=$2
    local cmdline="$3"
    local server="$4"
    local check_opt="$5"
    local nfsinfo opts found expected

    echo "CLIENT TEST START: $test_name"

    # Need this so kvm-qemu will boot (needs non-/dev/zero local disk)
    if ! dd if=/dev/zero of=$TESTDIR/client.img bs=1M count=1 &>/dev/null; then
        echo "Unable to make client sda image" 1>&2
        return 1
    fi

    $testdir/run-qemu \
        -drive format=raw,index=0,media=disk,file=$TESTDIR/client.img \
        -net nic,macaddr=$mac,model=e1000 \
        -net socket,connect=127.0.0.1:12320 \
        -watchdog i6300esb -watchdog-action poweroff \
        -append "rd.net.timeout.dhcp=3 panic=1 systemd.crash_reboot rd.shell=0 $cmdline $DEBUGFAIL rd.retry=10 quiet ro console=ttyS0,115200n81 selinux=0" \
        -initrd $TESTDIR/initramfs.testing

    if [[ $? -ne 0 ]] || ! grep -F -m 1 -q nfs-OK $TESTDIR/client.img; then
        echo "CLIENT TEST END: $test_name [FAILED - BAD EXIT]"
        return 1
    fi

    # nfsinfo=( server:/path nfs{,4} options )
    nfsinfo=($(awk '{print $2, $3, $4; exit}' $TESTDIR/client.img))

    if [[ "${nfsinfo[0]%%:*}" != "$server" ]]; then
        echo "CLIENT TEST INFO: got server: ${nfsinfo[0]%%:*}"
        echo "CLIENT TEST INFO: expected server: $server"
        echo "CLIENT TEST END: $test_name [FAILED - WRONG SERVER]"
        return 1
    fi

    found=0
    expected=1
    if [[ ${check_opt:0:1} = '-' ]]; then
        expected=0
        check_opt=${check_opt:1}
    fi

    opts=${nfsinfo[2]},
    while [[ $opts ]]; do
        if [[ ${opts%%,*} = $check_opt ]]; then
            found=1
            break
        fi
        opts=${opts#*,}
    done

    if [[ $found -ne $expected ]]; then
        echo "CLIENT TEST INFO: got options: ${nfsinfo[2]%%:*}"
        if [[ $expected -eq 0 ]]; then
            echo "CLIENT TEST INFO: did not expect: $check_opt"
            echo "CLIENT TEST END: $test_name [FAILED - UNEXPECTED OPTION]"
        else
            echo "CLIENT TEST INFO: missing: $check_opt"
            echo "CLIENT TEST END: $test_name [FAILED - MISSING OPTION]"
        fi
        return 1
    fi

    echo "CLIENT TEST END: $test_name [OK]"
    return 0
}

test_nfsv3() {
    # MAC numbering scheme:
    # NFSv3: last octect starts at 0x00 and works up
    # NFSv4: last octect starts at 0x80 and works up

    client_test "NFSv3 root=dhcp DHCP path only" 52:54:00:12:34:00 \
                "root=dhcp" 192.168.50.1 -wsize=4096 || return 1

    if [[ "$(systemctl --version)" != *"systemd 230"* ]] 2>/dev/null; then
        client_test "NFSv3 Legacy root=/dev/nfs nfsroot=IP:path" 52:54:00:12:34:01 \
                    "root=/dev/nfs nfsroot=192.168.50.1:/nfs/client" 192.168.50.1 -wsize=4096 || return 1

        client_test "NFSv3 Legacy root=/dev/nfs DHCP path only" 52:54:00:12:34:00 \
                    "root=/dev/nfs" 192.168.50.1 -wsize=4096 || return 1

        client_test "NFSv3 Legacy root=/dev/nfs DHCP IP:path" 52:54:00:12:34:01 \
                    "root=/dev/nfs" 192.168.50.2 -wsize=4096 || return 1
    fi

    client_test "NFSv3 root=dhcp DHCP IP:path" 52:54:00:12:34:01 \
                "root=dhcp" 192.168.50.2 -wsize=4096 || return 1

    client_test "NFSv3 root=dhcp DHCP proto:IP:path" 52:54:00:12:34:02 \
                "root=dhcp" 192.168.50.3 -wsize=4096 || return 1

    client_test "NFSv3 root=dhcp DHCP proto:IP:path:options" 52:54:00:12:34:03 \
                "root=dhcp" 192.168.50.3 wsize=4096 || return 1

    client_test "NFSv3 root=nfs:..." 52:54:00:12:34:04 \
                "root=nfs:192.168.50.1:/nfs/client" 192.168.50.1 -wsize=4096 || return 1

    client_test "NFSv3 Bridge root=nfs:..." 52:54:00:12:34:04 \
                "root=nfs:192.168.50.1:/nfs/client bridge net.ifnames=0" 192.168.50.1 -wsize=4096 || return 1

    client_test "NFSv3 Legacy root=IP:path" 52:54:00:12:34:04 \
                "root=192.168.50.1:/nfs/client" 192.168.50.1 -wsize=4096 || return 1

    # This test must fail: nfsroot= requires root=/dev/nfs
    client_test "NFSv3 Invalid root=dhcp nfsroot=/nfs/client" 52:54:00:12:34:04 \
                "root=dhcp nfsroot=/nfs/client failme rd.debug" 192.168.50.1 -wsize=4096 && return 1

    client_test "NFSv3 root=dhcp DHCP path,options" \
                52:54:00:12:34:05 "root=dhcp" 192.168.50.1 wsize=4096 || return 1

    client_test "NFSv3 Bridge Customized root=dhcp DHCP path,options" \
                52:54:00:12:34:05 "root=dhcp bridge=foobr0:ens2" 192.168.50.1 wsize=4096 || return 1

    client_test "NFSv3 root=dhcp DHCP IP:path,options" \
                52:54:00:12:34:06 "root=dhcp" 192.168.50.2 wsize=4096 || return 1

    client_test "NFSv3 root=dhcp DHCP proto:IP:path,options" \
                52:54:00:12:34:07 "root=dhcp" 192.168.50.3 wsize=4096 || return 1

    return 0
}

test_nfsv4() {
    # There is a mandatory 90 second recovery when starting the NFSv4
    # server, so put these later in the list to avoid a pause when doing
    # switch_root

    client_test "NFSv4 root=dhcp DHCP proto:IP:path" 52:54:00:12:34:82 \
                "root=dhcp" 192.168.50.3 -wsize=4096 || return 1

    client_test "NFSv4 root=dhcp DHCP proto:IP:path:options" 52:54:00:12:34:83 \
                "root=dhcp" 192.168.50.3 wsize=4096 || return 1

    client_test "NFSv4 root=nfs4:..." 52:54:00:12:34:84 \
                "root=nfs4:192.168.50.1:/client" 192.168.50.1 \
                -wsize=4096 || return 1

    client_test "NFSv4 root=dhcp DHCP proto:IP:path,options" \
                52:54:00:12:34:87 "root=dhcp" 192.168.50.3 wsize=4096 || return 1

    return 0
}

test_run() {
    if [[ -s server.pid ]]; then
        kill -TERM $(cat $TESTDIR/server.pid)
        rm -f -- $TESTDIR/server.pid
    fi

    if ! run_server; then
        echo "Failed to start server" 1>&2
        return 1
    fi

    test_nfsv3 && \
        test_nfsv4

    ret=$?

    if [[ -s $TESTDIR/server.pid ]]; then
        kill -TERM $(cat $TESTDIR/server.pid)
        rm -f -- $TESTDIR/server.pid
    fi

    return $ret
}

test_setup() {
    # Make server root
    dd if=/dev/null of=$TESTDIR/server.ext3 bs=1M seek=120
    mke2fs -j -F $TESTDIR/server.ext3
    mkdir $TESTDIR/mnt
    mount -o loop $TESTDIR/server.ext3 $TESTDIR/mnt


    export kernel=$KVERSION
    export srcmods="/lib/modules/$kernel/"
    # Detect lib paths

    (
        export initdir=$TESTDIR/mnt
        . $basedir/dracut-init.sh

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
                      /etc/services sleep mount chmod rm
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        type -P portmap >/dev/null && inst_multiple portmap
        type -P rpcbind >/dev/null && inst_multiple rpcbind
        [ -f /etc/netconfig ] && inst_multiple /etc/netconfig
        type -P dhcpd >/dev/null && inst_multiple dhcpd
        [ -x /usr/sbin/dhcpd3 ] && inst /usr/sbin/dhcpd3 /usr/sbin/dhcpd
        instmods nfsd sunrpc ipv6 lockd af_packet
        inst ./server-init.sh /sbin/init
        inst_simple /etc/os-release
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

        (
            cd "$initdir";
            mkdir -p dev sys proc run etc var/run tmp var/lib/{dhcpd,rpcbind}
            mkdir -p var/lib/nfs/{v4recovery,rpc_pipefs}
            chmod 777 var/lib/rpcbind var/lib/nfs
        )
        inst /etc/nsswitch.conf /etc/nsswitch.conf

        inst /etc/passwd /etc/passwd
        inst /etc/group /etc/group

        cp -a /etc/ld.so.conf* $initdir/etc
        ldconfig -r "$initdir"
        dracut_kernel_post
    )


    # Make client root inside server root
    (
        export initdir=$TESTDIR/mnt/nfs/client
        . $basedir/dracut-init.sh

        inst_multiple sh shutdown poweroff stty cat ps ln ip dd \
                      mount dmesg mkdir cp ping grep setsid ls vi /etc/virc less cat
        for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
            [ -f ${_terminfodir}/l/linux ] && break
        done
        inst_multiple -o ${_terminfodir}/l/linux
        inst ./client-init.sh /sbin/init
        inst_simple /etc/os-release
        (
            cd "$initdir"
            mkdir -p dev sys proc etc run
            mkdir -p var/lib/nfs/rpc_pipefs
            mkdir -p root usr/bin usr/lib usr/lib64 usr/sbin
            for i in bin sbin lib lib64; do
                ln -sfnr usr/$i $i
            done
        )
        inst /etc/nsswitch.conf /etc/nsswitch.conf
        inst /etc/passwd /etc/passwd
        inst /etc/group /etc/group

        inst_libdir_file 'libnfsidmap_nsswitch.so*'
        inst_libdir_file 'libnfsidmap/*.so*'
        inst_libdir_file 'libnfsidmap*.so*'

        _nsslibs=$(sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' /etc/nsswitch.conf \
                       |  tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|')
        _nsslibs=${_nsslibs#|}
        _nsslibs=${_nsslibs%|}

        inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

        cp -a /etc/ld.so.conf* $initdir/etc
        ldconfig -r "$initdir"
    )

    mkdir -p $TESTDIR/mnt/nfs/nfs3-5
    mkdir -p $TESTDIR/mnt/nfs/ip/192.168.50.101
    mkdir -p $TESTDIR/mnt/nfs/tftpboot/nfs4-5

    umount $TESTDIR/mnt
    rm -fr -- $TESTDIR/mnt

    # Make an overlay with needed tools for the test harness
    (
        export initdir=$TESTDIR/overlay
        . $basedir/dracut-init.sh
        mkdir $TESTDIR/overlay
        inst_multiple poweroff shutdown
        inst_hook shutdown-emergency 000 ./hard-off.sh
        inst_hook emergency 000 ./hard-off.sh
        inst_simple ./99-idesymlinks.rules /etc/udev/rules.d/99-idesymlinks.rules
        inst_simple ./99-default.link /etc/systemd/network/99-default.link
    )

    # Make server's dracut image
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -m "dash udev-rules base rootfs-block fs-lib debug kernel-modules watchdog qemu" \
                       -d "af_packet piix ide-gd_mod ata_piix ext3 sd_mod e1000 i6300esb" \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.server $KVERSION || return 1

    # Make client's dracut image
    $basedir/dracut.sh -l -i $TESTDIR/overlay / \
                       -o "plymouth dash ${OMIT_NETWORK}" \
                       -a "debug watchdog ${USE_NETWORK}" \
                       -d "af_packet piix ide-gd_mod ata_piix sd_mod e1000 nfs sunrpc i6300esb" \
                       --no-hostonly-cmdline -N \
                       -f $TESTDIR/initramfs.testing $KVERSION || return 1
}

test_cleanup() {
    if [[ -s $TESTDIR/server.pid ]]; then
        kill -TERM $(cat $TESTDIR/server.pid)
        rm -f -- $TESTDIR/server.pid
    fi
}

. $testdir/test-functions
