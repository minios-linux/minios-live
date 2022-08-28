#!/bin/bash

# called by dracut
check() {
    require_binaries stratisd-init thin_check thin_repair mkfs.xfs xfs_admin xfs_growfs || return 1
    return 255
}

# called by dracut
depends() {
    echo dm
    return 0
}

# called by dracut
installkernel() {
    instmods xfs
}

# called by dracut
install() {

    inst_multiple stratisd-init thin_check thin_repair mkfs.xfs xfs_admin xfs_growfs

    if dracut_module_included "systemd"; then
        inst_simple "${moddir}/stratisd-init.service" "${systemdsystemunitdir}/stratisd-init.service"
        systemctl -q --root "$initdir" enable stratisd-init.service
    else
        inst_hook pre-mount 25 "$moddir/stratisd-start.sh"
        inst_hook cleanup 25 "$moddir/stratisd-stop.sh"
    fi
}

