#!/bin/bash

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1
    require_binaries /sbin/bootchartd || return 1
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_symlink /init /sbin/init
    inst_dir /lib/bootchart/tmpfs

    inst_multiple bootchartd bash \
        /lib/bootchart/bootchart-collector /etc/bootchartd.conf \
        accton \
        echo \
        grep \
        usleep

    inst /usr/bin/pkill /bin/pkill
    inst /usr/bin/[  /bin/[
}

