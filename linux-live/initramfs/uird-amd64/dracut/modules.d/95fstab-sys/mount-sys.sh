#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type det_fs >/dev/null 2>&1 || . /lib/fs-lib.sh

fstab_mount() {
    local _dev _mp _fs _opts _dump _pass _rest
    test -e "$1" || return 1
    info "Mounting from $1"
    while read _dev _mp _fs _opts _dump _pass _rest || [ -n "$_dev" ]; do
        [ -z "${_dev%%#*}" ] && continue # Skip comment lines
        ismounted $_mp && continue # Skip mounted filesystem
        if [ "$_pass" -gt 0 ] && ! strstr "$_opts" _netdev; then
            fsck_single "$_dev" "$_fs" "$_opts"
        fi
        _fs=$(det_fs "$_dev" "$_fs")
        info "Mounting $_dev"
        if [ -d "$NEWROOT/$_mp" ]; then
            mount -v -t $_fs -o $_opts $_dev "$NEWROOT/$_mp" 2>&1 | vinfo
        else
            [ -d "$_mp" ] || mkdir -p "$_mp"
            mount -v -t $_fs -o $_opts $_dev $_mp 2>&1 | vinfo
        fi
    done < $1
    return 0
}

# systemd will mount and run fsck from /etc/fstab and we don't want to
# run into a race condition.
if [ -z "$DRACUT_SYSTEMD" ]; then
    [ -f /etc/fstab ] && fstab_mount /etc/fstab
fi

# prefer $NEWROOT/etc/fstab.sys over local /etc/fstab.sys
if [ -f $NEWROOT/etc/fstab.sys ]; then
    fstab_mount $NEWROOT/etc/fstab.sys
elif [ -f /etc/fstab.sys ]; then
    fstab_mount /etc/fstab.sys
fi
