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
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        [ -d /sys/firmware/efi ] || return 255
        for c in /sys/bus/fcoe/devices/ctlr_* ; do
            [ -L $c ] || continue
            fcoe_ctlr=$c
        done
        [ -z "$fcoe_ctlr" ] && return 255
    }
    require_binaries dcbtool fipvlan lldpad ip readlink || return 1
    return 0
}

# called by dracut
depends() {
    echo fcoe uefi-lib
    return 0
}

# called by dracut
install() {
    inst_hook cmdline 20 "$moddir/parse-uefifcoe.sh"
}
