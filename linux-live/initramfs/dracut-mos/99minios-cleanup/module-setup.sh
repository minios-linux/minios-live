#!/bin/bash
# MiniOS cleanup module - runs last to remove unnecessary files and patch init

check() {
    return 0
}

depends() {
    echo minios
    return 0
}

install() {
    # Remove unnecessary files to reduce initramfs size
    dinfo "*** MiniOS-cleanup: Removing unnecessary files"
    rm -f "${initdir}/usr/bin/loginctl"
    rm -f "${initdir}/usr/bin/findmnt"
    rm -f "${initdir}/usr/lib/udev/hwdb.bin"
    rm -rf "${initdir}/usr/lib/firmware"
    rm -f "${initdir}"/usr/lib/udev/*_id
    rm -f "${initdir}"/usr/lib/udev/hid2hci
    rm -f "${initdir}"/usr/lib/udev/mtd_probe

    # Patch the init script to suppress udevadm errors
    if [ -f "${initdir}/init" ]; then
        # Patch udevadm control --exit
        if grep -q '^udevadm control --exit$' "${initdir}/init" 2>/dev/null; then
            sed -i 's|^udevadm control --exit$|udevadm control --exit 2>/dev/null \|\| :|' "${initdir}/init"
            dinfo "*** MiniOS-cleanup: Patched 'udevadm control --exit'"
        fi
    fi

    return 0
}

installkernel() {
    # Decompress kernel modules for better final compression
    dinfo "*** MiniOS-cleanup: Decompressing kernel modules"
    find "${initdir}/usr/lib/modules" -name '*.ko.xz' -exec xz -d {} \; 2>/dev/null
    find "${initdir}/usr/lib/modules" -name '*.ko.zst' -exec zstd -d --rm {} \; 2>/dev/null

    return 0
}
