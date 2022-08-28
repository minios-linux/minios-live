#!/bin/bash

# called by dracut
check() {
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local _online=0
    [ "$_arch" = "s390" -o "$_arch" = "s390x" ] || return 1
    require_binaries /usr/lib/udev/collect || return 1
    dracut_module_included network || return 1

    [[ $hostonly ]] && {
        for i in /sys/devices/qeth/*/online; do
            read _online < $i
            [ $_online -eq 1 ] && return 0
	done
    }
    return 255
}

# called by dracut
installkernel() {
   instmods qeth
}

# called by dracut
install() {
    ccwid() {
        qeth_path=$(readlink -e -q $1/device)
        basename "$qeth_path"
    }

    inst_rules_qeth() {
        for rule in /etc/udev/rules.d/{4,5}1-qeth-${1}.rules; do
           # prefer chzdev generated 41- rules
           if [ -f "$rule" ]; then
              inst_rules "$rule"
              break
           fi
        done
    }

    has_carrier() {
        carrier=0
        # not readable in qeth interfaces
        # that have just been assembled, ignore
        # read error and assume no carrier
        read carrier 2>/dev/null < "$1/carrier"
        [ "$carrier" -eq 1 ] && return 0
        return 1;
    }

    for dev in /sys/class/net/*; do
        has_carrier $dev || continue
        id=$(ccwid $dev)
        [ -n "$id" ] && inst_rules_qeth $id
    done

    inst_simple /usr/lib/udev/collect
}
