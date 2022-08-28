#!/bin/bash
# module-setup for img-lib

# called by dracut
check() {
    require_binaries tar gzip dd bash || return 1
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_multiple tar gzip dd bash
    # TODO: make this conditional on a cmdline flag / config option
    inst_multiple -o cpio xz bzip2 zstd
    inst_simple "$moddir/img-lib.sh" "/lib/img-lib.sh"
}

