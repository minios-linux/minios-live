#!/bin/bash

# called by dracut
check() {
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ "$fs" == "9p" ]] && return 0
        done
        return 255
    }

    is_qemu_virtualized && return 0

    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    instmods 9p 9pnet_virtio virtio_pci
}

# called by dracut
install() {
    inst_hook cmdline 95 "$moddir/parse-virtfs.sh"
    inst_hook mount 99 "$moddir/mount-virtfs.sh"
}
