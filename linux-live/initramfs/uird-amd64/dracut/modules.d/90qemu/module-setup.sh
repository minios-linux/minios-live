#!/bin/bash

# called by dracut
check() {
    if [[ $hostonly ]] || [[ $mount_needs ]]; then
        is_qemu_virtualized && return 0
        return 255
    fi

    return 0
}

# called by dracut
installkernel() {
    # qemu specific modules
    hostonly='' instmods \
            ata_piix ata_generic pata_acpi cdrom sr_mod ahci \
            virtio_blk virtio virtio_ring virtio_pci \
            virtio_scsi virtio_console virtio_rng \
            spapr-vscsi \
            qemu_fw_cfg
}
