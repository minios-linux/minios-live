#!/bin/bash

# called by dracut
check() {
    # do not add this module by default
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_multiple -o ls ps grep more cat rm strace free showmount df du lsblk \
                  ping netstat rpcinfo vi scp ping6 ssh find \
                  tcpdump cp dd less hostname mkdir systemd-analyze \
                  fsck fsck.ext2 fsck.ext4 fsck.ext3 fsck.ext4dev fsck.f2fs fsck.vfat e2fsck

    grep '^tcpdump:' $dracutsysrootdir/etc/passwd 2>/dev/null >> "$initdir/etc/passwd"
}

