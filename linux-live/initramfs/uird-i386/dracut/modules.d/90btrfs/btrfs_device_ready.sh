#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

btrfs_check_complete() {
    local _rootinfo _dev
    _dev="${1:-/dev/root}"
    [ -e "$_dev" ] || return 0
    _rootinfo=$(udevadm info --query=env "--name=$_dev" 2>/dev/null)
    if strstr "$_rootinfo" "ID_FS_TYPE=btrfs"; then
        info "Checking, if btrfs device complete"
        btrfs device ready "$_dev" >/dev/null 2>&1
        return $?
    fi
    return 0
}

btrfs_check_complete $1
exit $?
