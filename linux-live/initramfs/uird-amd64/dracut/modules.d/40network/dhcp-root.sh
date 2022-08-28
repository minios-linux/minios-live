#!/bin/sh

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)

if [ -z "$netroot" ]; then
    for netroot in $(getargs netroot=); do
        [ "$netroot" = "dhcp" ] && break
        [ "$netroot" = "dhcp6" ] && break
    done
    [ "$netroot" = "dhcp" ] || [ "$netroot" = "dhcp6" ] || unset netroot
fi

if [ "$root" = "dhcp" ] || [ "$root" = "dhcp6" ] || [ "$netroot" = "dhcp" ] || [ "$netroot" = "dhcp6" ]; then
    # Tell ip= checker that we need dhcp
    NEEDDHCP="1"

    # Done, all good!
    rootok=1
    if [ "$netroot" != "dhcp" ] && [ "$netroot" != "dhcp6" ]; then
        netroot=$root
    fi

    # Shut up init error check
    [ -z "$root" ] && root="dhcp"
    echo '[ -d $NEWROOT/proc -o -e /dev/root ]' > $hookdir/initqueue/finished/dhcp.sh
fi
