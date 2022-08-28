#!/bin/bash

check() {
    return 255
}

depends() {
    echo "bash systemd systemd-initrd"
    return 0
}

installkernel() {
    hostonly="" instmods -c squashfs loop overlay
}

install() {
    if ! type -P mksquashfs >/dev/null || ! type -P unsquashfs >/dev/null ; then
        derror "squash module requires squashfs-tools to be installed."
        return 1
    fi

    inst_multiple kmod modprobe mount mkdir ln echo
    inst $moddir/setup-squash.sh /squash/setup-squash.sh
    inst $moddir/clear-squash.sh /squash/clear-squash.sh
    inst $moddir/init.sh /squash/init.sh

    inst "$moddir/squash-mnt-clear.service" "$systemdsystemunitdir/squash-mnt-clear.service"
    systemctl -q --root "$initdir" add-wants initrd-switch-root.target squash-mnt-clear.service
}
