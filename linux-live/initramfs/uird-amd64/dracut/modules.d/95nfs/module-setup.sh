#!/bin/bash

# called by dracut
check() {
    # If our prerequisites are not met, fail anyways.
    require_any_binary rpcbind portmap || return 1
    require_binaries rpc.statd mount.nfs mount.nfs4 umount || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ "$fs" == "nfs" ]] && return 0
            [[ "$fs" == "nfs3" ]] && return 0
            [[ "$fs" == "nfs4" ]] && return 0
        done
        return 255
    }
    return 0
}

# called by dracut
depends() {
    # We depend on network modules being loaded
    echo network
}

# called by dracut
installkernel() {
    hostonly='' instmods =net/sunrpc =fs/nfs ipv6 nfs_acl nfs_layout_nfsv41_files
}

cmdline() {
    local nfs_device
    local nfs_options
    local nfs_root
    local nfs_address
    local lookup
    local ifname

    ### nfsroot= ###
    nfs_device=$(findmnt -t nfs4 -n -o SOURCE /)
    if [ -n "$nfs_device" ];then
        nfs_root="root=nfs4:$nfs_device"
    else
        nfs_device=$(findmnt -t nfs -n -o SOURCE /)
        [ -z "$nfs_device" ] && return
        nfs_root="root=nfs:$nfs_device"
    fi
    nfs_options=$(findmnt -t nfs4,nfs -n -o OPTIONS /)
    [ -n "$nfs_options" ] && nfs_root="$nfs_root:$nfs_options"
    echo "$nfs_root"

    ### ip= ###
    if [[ $nfs_device = [0-9]*\.[0-9]*\.[0-9]*.[0-9]* ]] || [[ $nfs_device = \[.*\] ]]; then
        nfs_address="${nfs_device%%:*}"
    else
        lookup=$(host "${nfs_device%%:*}"| grep " address " | head -n1)
        nfs_address=${lookup##* }
    fi
    ifname=$(ip -o route get to $nfs_address | sed -n 's/.*dev \([^ ]*\).*/\1/p')
    if [ -d /sys/class/net/$ifname/bonding ]; then
        dinfo "Found bonded interface '${ifname}'. Make sure to provide an appropriate 'bond=' cmdline."
        return
    elif [ -e /sys/class/net/$ifname/address ] ; then
        ifmac=$(cat /sys/class/net/$ifname/address)
        printf 'ifname=%s:%s ' ${ifname} ${ifmac}
    fi

    bootproto=$(sed -n "/BOOTPROTO/s/BOOTPROTO='\([[:alpha:]]*6\?\)4\?'/\1/p" /etc/sysconfig/network/ifcfg-$ifname)
    if [ $bootproto ]; then
        printf 'ip=%s:%s ' ${ifname} ${bootproto}
    else
        printf 'ip=%s:static ' ${ifname}
    fi
}

# called by dracut
install() {
    local _i
    local _nsslibs
    inst_multiple -o portmap rpcbind rpc.statd mount.nfs \
        mount.nfs4 umount rpc.idmapd sed /etc/netconfig chmod "$tmpfilesdir/rpcbind.conf"
    inst_multiple /etc/services /etc/nsswitch.conf /etc/rpc /etc/protocols /etc/idmapd.conf

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _netconf="$(cmdline)"
        [[ $_netconf ]] && printf "%s\n" "$_netconf" >> "${initdir}/etc/cmdline.d/95nfs.conf"
    fi

    if [ -f $dracutsysrootdir/lib/modprobe.d/nfs.conf ]; then
        inst_multiple /lib/modprobe.d/nfs.conf
    else
        [ -d $initdir/etc/modprobe.d/ ] || mkdir $initdir/etc/modprobe.d
        echo "alias nfs4 nfs" > $initdir/etc/modprobe.d/nfs.conf
    fi

    inst_libdir_file 'libnfsidmap_nsswitch.so*' 'libnfsidmap/*.so' 'libnfsidmap*.so*'

    _nsslibs=$(sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' $dracutsysrootdir/etc/nsswitch.conf \
        |  tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|')
    _nsslibs=${_nsslibs#|}
    _nsslibs=${_nsslibs%|}

    inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

    inst_hook cmdline 90 "$moddir/parse-nfsroot.sh"
    inst_hook pre-udev 99 "$moddir/nfs-start-rpc.sh"
    inst_hook cleanup 99 "$moddir/nfsroot-cleanup.sh"
    inst "$moddir/nfsroot.sh" "/sbin/nfsroot"
    inst "$moddir/nfs-lib.sh" "/lib/nfs-lib.sh"
    mkdir -m 0755 -p "$initdir/var/lib/nfs/rpc_pipefs"
    mkdir -m 0770 -p "$initdir/var/lib/rpcbind"
    mkdir -m 0755 -p "$initdir/var/lib/nfs/statd/sm"

    # Rather than copy the passwd file in, just set a user for rpcbind
    # We'll save the state and restart the daemon from the root anyway
    grep -E '^nfsnobody:|^rpc:|^rpcuser:' $dracutsysrootdir/etc/passwd >> "$initdir/etc/passwd"
    grep -E '^nogroup:|^rpc:|^nobody:' $dracutsysrootdir/etc/group >> "$initdir/etc/group"

    # rpc user needs to be able to write to this directory to save the warmstart
    # file
    chmod 770 "$initdir/var/lib/rpcbind"
    grep -q '^rpc:' $dracutsysrootdir/etc/passwd \
        && grep -q '^rpc:' $dracutsysrootdir/etc/group
    dracut_need_initqueue
}
