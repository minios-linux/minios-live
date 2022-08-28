#!/bin/bash

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1
    require_binaries biosdevname || return 1
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_multiple biosdevname
    inst_rules 71-biosdevname.rules
}

