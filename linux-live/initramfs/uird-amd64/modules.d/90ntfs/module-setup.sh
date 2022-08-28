#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    return 0
}

depends() {
    return 0
}

installkernel() {
    instmods fuse ntfs
}

install() {
    for a in $(find /lib /usr/lib  -name 'libntfs*so*') ;do
        inst $a $a
    done
    inst "$moddir/ntfsmount" /bin/ntfsmount
    dracut_install mount.ntfs-3g ntfs-3g ntfsfix ntfs-3g.probe
}

