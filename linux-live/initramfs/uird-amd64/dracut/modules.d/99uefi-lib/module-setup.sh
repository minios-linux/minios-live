#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    echo bash
    return 0
}

# called by dracut
install() {
    inst_simple "$moddir/uefi-lib.sh" "/lib/uefi-lib.sh"
}

