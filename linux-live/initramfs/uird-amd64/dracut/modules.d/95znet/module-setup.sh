#!/bin/bash

# called by dracut
check() {
    arch=${DRACUT_ARCH:-$(uname -m)}
    [ "$arch" = "s390" -o "$arch" = "s390x" ] || return 1

    require_binaries znet_cio_free grep sed seq readlink || return 1

    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    instmods ctcm lcs qeth qeth_l2 qeth_l3
}

# called by dracut
install() {
    inst_hook cmdline 30 "$moddir/parse-ccw.sh"
    inst_rules 81-ccw.rules
    inst_multiple znet_cio_free grep sed seq readlink /lib/udev/ccw_init
}

