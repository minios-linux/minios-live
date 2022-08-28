#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1
    return 0
}

# called by dracut
depends() {
    echo 'fs-lib'
}

# called by dracut
install() {
    if ! dracut_module_included "systemd"; then
        inst_hook pre-pivot 50 "$moddir/mount-usr.sh"
    fi
    :
}

