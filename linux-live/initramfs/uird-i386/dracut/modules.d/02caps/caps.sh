#!/bin/bash

capsmode=$(getarg rd.caps)

if [ "$capsmode" = "1" ]; then
    CAPS_INIT_DROP=$(getarg rd.caps.initdrop=)
    CAPS_USERMODEHELPER_BSET=$(capsh --drop="$CAPS_INIT_DROP" -- -c 'while read a b  || [ -n "$a" ]; do [ "$a" = "CapBnd:" ] && echo $((0x${b:$((${#b}-8)):8})) $((0x${b:$((${#b}-16)):8})) && break; done < /proc/self/status')
    CAPS_MODULES_DISABLED=$(getarg rd.caps.disablemodules=)
    CAPS_KEXEC_DISABLED=$(getarg rd.caps.disablekexec=)

    info "Loading CAPS_MODULES $CAPS_MODULES"
    for i in $CAPS_MODULES;do modprobe $i 2>&1 >/dev/null | vinfo; done

    if [ "$CAPS_MODULES_DISABLED" = "1" -a -e /proc/sys/kernel/modules_disabled ]; then
        info "Disabling module loading."
        echo $CAPS_MODULES_DISABLED > /proc/sys/kernel/modules_disabled
    fi

    if [ "$CAPS_KEXEC_DISABLED" = "1" -a -e /proc/sys/kernel/kexec_disabled ]; then
        info "Disabling kexec."
        echo $CAPS_KEXEC_DISABLED > /proc/sys/kernel/kexec_disabled
    fi

    info "CAPS_USERMODEHELPER_BSET=$CAPS_USERMODEHELPER_BSET"
    if [ -e /proc/sys/kernel/usermodehelper/bset ]; then
        info "Setting usermode helper bounding set."
        echo $CAPS_USERMODEHELPER_BSET > /proc/sys/kernel/usermodehelper/bset
        echo $CAPS_USERMODEHELPER_BSET > /proc/sys/kernel/usermodehelper/inheritable
    fi

    echo "CAPS_INIT_DROP=\"$CAPS_INIT_DROP\"" > /etc/capsdrop
    info "Will drop capabilities $CAPS_INIT_DROP from init."
fi

