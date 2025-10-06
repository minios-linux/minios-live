#!/bin/bash
# MiniOS cleanup module - runs last to remove unnecessary files

check() {
    return 0
}

depends() {
    echo minios
    return 0
}

install() {
    rm -f "${initdir}/usr/bin/loginctl"
    rm -f "${initdir}/usr/bin/findmnt"
    rm -f "${initdir}/usr/lib/udev/hwdb.bin"
    rm -rf "${initdir}/usr/lib/firmware"
    rm -f "${initdir}"/usr/lib/udev/*_id
    rm -f "${initdir}"/usr/lib/udev/hid2hci
    rm -f "${initdir}"/usr/lib/udev/mtd_probe
    
    return 0
}

installkernel() {
    # Decompress kernel modules for better final compression
    find "${initdir}/usr/lib/modules" -name '*.ko.xz' -exec xz -d {} \; 2>/dev/null
    find "${initdir}/usr/lib/modules" -name '*.ko.zst' -exec zstd -d --rm {} \; 2>/dev/null
    
    return 0
}
