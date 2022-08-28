#!/bin/bash

# called by dracut
check() {
    local _fcoe_ctlr
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for c in /sys/bus/fcoe/devices/ctlr_* ; do
            [ -L $c ] || continue
            _fcoe_ctlr=$c
        done
        [ -z "$_fcoe_ctlr" ] && return 255
    }

    require_binaries dcbtool fipvlan lldpad ip readlink fcoemon fcoeadm || return 1
    return 0
}

# called by dracut
depends() {
    echo network rootfs-block
    return 0
}

# called by dracut
installkernel() {
    instmods fcoe 8021q edd
}

get_vlan_parent() {
    local link=$1

    [ -d $link ] || return
    read iflink < $link/iflink
    for if in /sys/class/net/* ; do
	read idx < $if/ifindex
	if [ $idx -eq $iflink ] ; then
	    echo ${if##*/}
	fi
    done
}

# called by dracut
cmdline() {
    {
        for c in /sys/bus/fcoe/devices/ctlr_* ; do
            [ -L $c ] || continue
            read enabled < $c/enabled
            read mode < $c/mode
            [ $enabled -eq 0 ] && continue
            if [ $mode = "VN2VN" ] ; then
                mode="vn2vn"
            else
                mode="fabric"
            fi
            d=$(cd -P $c; echo $PWD)
            i=${d%/*}
            ifname=${i##*/}
            read mac < ${i}/address
            s=$(dcbtool gc ${i##*/} dcb 2>/dev/null | sed -n 's/^DCB State:\t*\(.*\)/\1/p')
            if [ -z "$s" ] ; then
	        p=$(get_vlan_parent ${i})
	        if [ "$p" ] ; then
	            s=$(dcbtool gc ${p} dcb 2>/dev/null | sed -n 's/^DCB State:\t*\(.*\)/\1/p')
                    ifname=${p##*/}
	        fi
            fi
            if [ "$s" = "on" ] ; then
	        dcb="dcb"
            else
	        dcb="nodcb"
            fi

            # Some Combined Network Adapters(CNAs) implement DCB in firmware.
            # Do not run software-based DCB or LLDP on CNAs that implement DCB.
            # If the network interface provides hardware DCB/DCBX capabilities,
            # DCB_REQUIRED in "/etc/fcoe/cfg-xxx" is expected to set to "no".
            #
            # Force "nodcb" if there's any DCB_REQUIRED="no"(child or vlan parent).
            grep -q "^[[:blank:]]*DCB_REQUIRED=\"no\"" /etc/fcoe/cfg-${i##*/} &>/dev/null
            [ $? -eq 0 ] && dcb="nodcb"
            if [ "$p" ] ; then
                grep -q "^[[:blank:]]*DCB_REQUIRED=\"no\"" /etc/fcoe/cfg-${p} &>/dev/null
                [ $? -eq 0 ] && dcb="nodcb"
            fi

            echo "ifname=${ifname}:${mac}"
            echo "fcoe=${ifname}:${dcb}:${mode}"
        done
    } | sort | uniq
}

# called by dracut
install() {
    inst_multiple ip dcbtool fipvlan lldpad readlink lldptool fcoemon fcoeadm
    if [ -e "$dracutsysrootdir/etc/hba.conf" ]; then
        inst_libdir_file 'libhbalinux.so*'
        inst_simple "/etc/hba.conf"
    fi

    mkdir -m 0755 -p "$initdir/var/lib/lldpad"
    mkdir -m 0755 -p "$initdir/etc/fcoe"

    if [[ $hostonly_cmdline == "yes" ]] ; then
        local _fcoeconf=$(cmdline)
        [[ $_fcoeconf ]] && printf "%s\n" "$_fcoeconf" >> "${initdir}/etc/cmdline.d/95fcoe.conf"
    fi
    inst_multiple /etc/fcoe/cfg-*

    inst "$moddir/fcoe-up.sh" "/sbin/fcoe-up"
    inst "$moddir/fcoe-edd.sh" "/sbin/fcoe-edd"
    inst "$moddir/fcoe-genrules.sh" "/sbin/fcoe-genrules.sh"
    inst_hook pre-trigger 03 "$moddir/lldpad.sh"
    inst_hook cmdline 99 "$moddir/parse-fcoe.sh"
    inst_hook cleanup 90 "$moddir/cleanup-fcoe.sh"
    inst_hook shutdown 40 "$moddir/stop-fcoe.sh"
    dracut_need_initqueue
}

