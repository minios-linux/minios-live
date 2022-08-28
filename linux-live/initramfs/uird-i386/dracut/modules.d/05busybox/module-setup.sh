#!/bin/bash

# called by dracut
check() {
    require_binaries busybox || return 1

    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    local _i _progs _path _busybox
    _busybox=$(type -P busybox)
    inst $_busybox /usr/bin/busybox
    for _i in $($_busybox | sed -ne '1,/Currently/!{s/,//g; s/busybox//g; p}')
    do
        _progs="$_progs $_i"
    done

    for _i in $_progs; do
        _path=$(find_binary "$_i")
        [ -z "$_path" ] && continue
        ln_r /usr/bin/busybox $_path
    done
}

