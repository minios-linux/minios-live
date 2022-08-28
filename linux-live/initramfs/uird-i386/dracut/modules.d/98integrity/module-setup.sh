#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    echo masterkey securityfs
    return 0
}

# called by dracut
install() {
    dracut_install evmctl keyctl ls
    inst_hook pre-pivot 61 "$moddir/evm-enable.sh"
    inst_hook pre-pivot 61 "$moddir/ima-keys-load.sh"
    inst_hook pre-pivot 62 "$moddir/ima-policy-load.sh"
}
