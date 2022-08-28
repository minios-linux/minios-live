#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    echo masterkey
    return 0
}

# called by dracut
installkernel() {
    instmods ecryptfs
}

# called by dracut
install() {
    inst_hook pre-pivot 63 "$moddir/ecryptfs-mount.sh"
}
