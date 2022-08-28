#!/bin/sh

_remove_dm() {
    local dev=$1
    local s
    local devname

    for s in /sys/block/${dev}/holders/dm-* ; do
        [ -e ${s} ] || continue
        _remove_dm ${s##*/}
    done
    # multipath devices might have MD devices on top,
    # which are removed after this script. So do not
    # remove those to avoid spurious errors
    case $(cat /sys/block/${dev}/dm/uuid) in
        mpath-*)
            return 0
            ;;
        *)
            devname=$(cat /sys/block/${dev}/dm/name)
            dmsetup -v --noudevsync remove "$devname" || return $?
            ;;
    esac
    return 0
}

_do_dm_shutdown() {
    local ret=0
    local final=$1
    local dev

    info "Disassembling device-mapper devices"
    for dev in /sys/block/dm-* ; do
        [ -e ${dev} ] || continue
        if [ "x$final" != "x" ]; then
            _remove_dm ${dev##*/} || ret=$?
        else
            _remove_dm ${dev##*/} >/dev/null 2>&1 || ret=$?
        fi
    done
    if [ "x$final" != "x" ]; then
        info "dmsetup ls --tree"
        dmsetup ls --tree 2>&1 | vinfo
    fi
    return $ret
}

if command -v dmsetup >/dev/null &&
    [ "x$(dmsetup status)" != "xNo devices found" ]; then
    _do_dm_shutdown $1
else
    :
fi
