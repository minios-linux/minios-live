#!/bin/bash

# called by dracut
check() {
    require_binaries dmsetup || return 1
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    instmods =drivers/md dm_mod dm-cache dm-cache-mq dm-cache-cleaner
}

# called by dracut
install() {
    modinfo -k $kernel dm_mod >/dev/null 2>&1 && \
        inst_hook pre-udev 30 "$moddir/dm-pre-udev.sh"

    inst_multiple dmsetup
    inst_multiple -o dmeventd

    inst_libdir_file "libdevmapper-event.so*"

    inst_rules 10-dm.rules 13-dm-disk.rules 95-dm-notify.rules
    # Gentoo ebuild for LVM2 prior to 2.02.63-r1 doesn't install above rules
    # files, but provides the one below:
    inst_rules 64-device-mapper.rules
    # debian udev rules
    inst_rules 60-persistent-storage-dm.rules 55-dm.rules

    inst_rules "$moddir/11-dm.rules"

    inst_rules "$moddir/59-persistent-storage-dm.rules"
    prepare_udev_rules 59-persistent-storage-dm.rules

    inst_hook shutdown 25 "$moddir/dm-shutdown.sh"
}

