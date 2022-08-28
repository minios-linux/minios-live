#!/bin/bash

# called by dracut
cmdline() {
    is_dasd() {
        local _dev=$1
        local _devpath=$(cd -P /sys/dev/block/$_dev ; echo $PWD)

        [ "${_devpath#*/dasd}" == "$_devpath" ] && return 1
        _ccw="${_devpath%%/block/*}"
        echo "rd.dasd=${_ccw##*/}"
        return 0
    }
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for_each_host_dev_and_slaves_all is_dasd || return 255
    } | sort | uniq
}

# called by dracut
check() {
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local found=0
    local bdev
    [ "$_arch" = "s390" -o "$_arch" = "s390x" ] || return 1
    require_binaries /usr/lib/udev/collect || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for bdev in /sys/block/* ; do
            case "${bdev##*/}" in
                dasd*)
                    found=$(($found+1));
                    break;
            esac
        done
        [ $found -eq 0 ] && return 255
    }
    return 0
}

# called by dracut
depends() {
    echo 'dasd_mod'
    return 0
}

# called by dracut
install() {
    inst_multiple /usr/lib/udev/collect
    inst_hook cmdline 30 "$moddir/parse-dasd.sh"
    if [[ $hostonly_cmdline == "yes" ]] ; then
        local _dasd=$(cmdline)
        [[ $_dasd ]] && printf "%s\n" "$_dasd" >> "${initdir}/etc/cmdline.d/95dasd.conf"
    fi
    if [[ $hostonly ]] ; then
        inst_rules_wildcard 51-dasd-*.rules
        inst_rules_wildcard 41-s390x-dasd-*.rules
        mark_hostonly /etc/udev/rules.d/51-dasd-*.rules
        mark_hostonly /etc/udev/rules.d/41-s390x-dasd-*.rules
    fi
    inst_rules 59-dasd.rules
}
