#!/bin/bash

pkglib_dir() {
    local _dirs="/usr/lib/plymouth /usr/libexec/plymouth/"
    if type -P dpkg-architecture &>/dev/null; then
        _dirs+=" /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/plymouth"
    fi
    for _dir in $_dirs; do
        if [ -x $dracutsysrootdir$_dir/plymouth-populate-initrd ]; then
            echo $_dir
            return
        fi
    done
}

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1
    [ -z $(pkglib_dir) ] && return 1

    require_binaries plymouthd plymouth plymouth-set-default-theme
}

# called by dracut
depends() {
    echo drm
}

# called by dracut
install() {
    PKGLIBDIR=$(pkglib_dir)
    if grep -q nash $dracutsysrootdir${PKGLIBDIR}/plymouth-populate-initrd \
        || [ ! -x $dracutsysrootdir${PKGLIBDIR}/plymouth-populate-initrd ]; then
        . "$moddir"/plymouth-populate-initrd.sh
    else
        PLYMOUTH_POPULATE_SOURCE_FUNCTIONS="$dracutfunctions" \
            $dracutsysrootdir${PKGLIBDIR}/plymouth-populate-initrd -t "$initdir"
    fi

    inst_hook emergency 50 "$moddir"/plymouth-emergency.sh

    inst_multiple readlink

    if ! dracut_module_included "systemd"; then
        inst_hook pre-trigger 10 "$moddir"/plymouth-pretrigger.sh
        inst_hook pre-pivot 90 "$moddir"/plymouth-newroot.sh
    fi
}

