#!/bin/sh

_do_md_shutdown() {
    local ret
    local final=$1
    local _offroot=$(strstr "$(mdadm --help-options 2>&1)" offroot && echo --offroot)
    info "Waiting for mdraid devices to be clean."
    mdadm $_offroot -vv --wait-clean --scan| vinfo
    ret=$?
    info "Disassembling mdraid devices."
    mdadm $_offroot -vv --stop --scan | vinfo
    ret=$(($ret+$?))
    if [ "x$final" != "x" ]; then
        info "/proc/mdstat:"
        vinfo < /proc/mdstat
    fi
    return $ret
}

if command -v mdadm >/dev/null; then
    _do_md_shutdown $1
else
    :
fi
