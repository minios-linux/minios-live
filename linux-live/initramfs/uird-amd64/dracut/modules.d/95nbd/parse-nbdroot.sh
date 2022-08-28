#!/bin/sh
#
# Preferred format:
#       root=nbd:srv:port/exportname[:fstype[:rootflags[:nbdopts]]]
#       [root=*] netroot=nbd:srv:port/exportname[:fstype[:rootflags[:nbdopts]]]
#
# nbdopts is a comma separated list of options to give to nbd-client
#
# root= takes precedence over netroot= if root=nbd[...]
#

# Sadly there's no easy way to split ':' separated lines into variables
netroot_to_var() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done

    unset server port
    server=$2; port=$3;
}

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)

if [ -z "$netroot" ]; then
    for netroot in $(getargs netroot=); do
        [ "${netroot%%:*}" = "nbd" ] && break
    done
    [ "${netroot%%:*}" = "nbd" ] || unset netroot
fi

# Root takes precedence over netroot
if [ "${root%%:*}" = "nbd" ] ; then
    if [ -n "$netroot" ] ; then
        warn "root takes precedence over netroot. Ignoring netroot"

    fi
    netroot=$root
    unset root
fi

# If it's not nbd we don't continue
[ "${netroot%%:*}" = "nbd" ] || return


#if [ -n "${DRACUT_SYSTEMD}" ] && [ "$root" = "dhcp" ]; then
#    echo "root=$netroot" > /etc/cmdline.d/root.conf
#    systemctl --no-block daemon-reload
#fi

# Check required arguments
netroot_to_var $netroot
[ -z "$server" ] && die "Argument server for nbdroot is missing"
[ -z "$port" ] && die "Argument port for nbdroot is missing"

# NBD actually supported?
incol2 /proc/devices nbd || modprobe nbd || die "nbdroot requested but kernel/initrd does not support nbd"

# Done, all good!
rootok=1

# Shut up init error check
if [ -z "$root" ]; then
    root=block:/dev/root
    wait_for_dev -n /dev/root
fi

