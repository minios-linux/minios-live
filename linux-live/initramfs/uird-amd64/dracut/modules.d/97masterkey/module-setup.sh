#!/bin/bash

# called by dracut
check() {
    [[ $hostonly ]] && {
        require_binaries keyctl uname || return 1
    }

    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    instmods trusted encrypted
}

# called by dracut
install() {
    inst_multiple keyctl uname
    inst_hook pre-pivot 60 "$moddir/masterkey.sh"
}
