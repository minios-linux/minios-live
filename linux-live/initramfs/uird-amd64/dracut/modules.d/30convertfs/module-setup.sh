#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_multiple bash find ldconfig mv rm cp ln
    inst_hook pre-pivot 99 "$moddir/do-convertfs.sh"
    inst_script "$moddir/convertfs.sh" /usr/bin/convertfs
}

