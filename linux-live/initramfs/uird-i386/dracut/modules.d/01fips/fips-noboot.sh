#!/bin/sh

if ! fipsmode=$(getarg fips) || [ "$fipsmode" = "0" ]; then
    rm -f -- /etc/modprobe.d/fips.conf >/dev/null 2>&1
elif [ -z "$fipsmode" ]; then
    die "FIPS mode have to be enabled by 'fips=1' not just 'fips'"
elif ! [ -f /tmp/fipsdone ]; then
    . /sbin/fips.sh
    mount_boot
    do_fips || die "FIPS integrity test failed"
fi
