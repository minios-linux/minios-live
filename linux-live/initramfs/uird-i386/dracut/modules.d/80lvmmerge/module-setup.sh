#!/bin/bash

# called by dracut
check() {
    # No point trying to support lvm if the binaries are missing
    require_binaries lvm dd swapoff || return 1

    return 255
}

# called by dracut
depends() {
    echo lvm dracut-systemd systemd
    return 0
}

installkernel() {
    hostonly="" instmods dm-snapshot
}

# called by dracut
install() {
    inst_multiple dd swapoff
    inst_hook cleanup 01 "$moddir/lvmmerge.sh"
}
