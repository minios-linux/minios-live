#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1

    if ! dracut_module_included "systemd-initrd"; then
        derror "dracut-systemd needs systemd-initrd in the initramfs"
        return 1
    fi

    return 0
}

# called by dracut
depends() {
    echo "systemd-initrd"
    return 0
}

installkernel() {
    return 0
}

# called by dracut
install() {
    local _mods
    inst_script "$moddir/dracut-emergency.sh" /bin/dracut-emergency
    inst_simple "$moddir/emergency.service" ${systemdsystemunitdir}/emergency.service
    inst_simple "$moddir/dracut-emergency.service" ${systemdsystemunitdir}/dracut-emergency.service
    inst_simple "$moddir/emergency.service" ${systemdsystemunitdir}/rescue.service

    ln_r "${systemdsystemunitdir}/initrd.target" "${systemdsystemunitdir}/default.target"

    inst_script "$moddir/dracut-cmdline.sh" /bin/dracut-cmdline
    inst_script "$moddir/dracut-cmdline-ask.sh" /bin/dracut-cmdline-ask
    inst_script "$moddir/dracut-pre-udev.sh" /bin/dracut-pre-udev
    inst_script "$moddir/dracut-pre-trigger.sh" /bin/dracut-pre-trigger
    inst_script "$moddir/dracut-initqueue.sh" /bin/dracut-initqueue
    inst_script "$moddir/dracut-pre-mount.sh" /bin/dracut-pre-mount
    inst_script "$moddir/dracut-mount.sh" /bin/dracut-mount
    inst_script "$moddir/dracut-pre-pivot.sh" /bin/dracut-pre-pivot

    inst_script "$moddir/rootfs-generator.sh" $systemdutildir/system-generators/dracut-rootfs-generator

    for i in \
        dracut-cmdline.service \
        dracut-cmdline-ask.service \
        dracut-initqueue.service \
        dracut-mount.service \
        dracut-pre-mount.service \
        dracut-pre-pivot.service \
        dracut-pre-trigger.service \
        dracut-pre-udev.service \
        ; do
        inst_simple "$moddir/${i}" "$systemdsystemunitdir/${i}"
        systemctl -q --root "$initdir" add-wants initrd.target "$i"
    done

    inst_simple "$moddir/dracut-tmpfiles.conf" "$tmpfilesdir/dracut-tmpfiles.conf"

    inst_multiple sulogin
}

