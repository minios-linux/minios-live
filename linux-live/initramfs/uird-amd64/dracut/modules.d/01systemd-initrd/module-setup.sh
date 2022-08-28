#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1

    if ! dracut_module_included "systemd"; then
        derror "systemd-initrd needs systemd in the initramfs"
        return 1
    fi

    return 0
}

# called by dracut
depends() {
    echo "systemd"
}

installkernel() {
    return 0
}

# called by dracut
install() {
    local _mods

    inst_multiple -o \
        $systemdsystemunitdir/initrd.target \
        $systemdsystemunitdir/initrd-fs.target \
        $systemdsystemunitdir/initrd-root-device.target \
        $systemdsystemunitdir/initrd-root-fs.target \
        $systemdsystemunitdir/initrd-switch-root.target \
        $systemdsystemunitdir/initrd-switch-root.service \
        $systemdsystemunitdir/initrd-cleanup.service \
        $systemdsystemunitdir/initrd-udevadm-cleanup-db.service \
        $systemdsystemunitdir/initrd-parse-etc.service

    systemctl -q --root "$initdir" set-default initrd.target
}
