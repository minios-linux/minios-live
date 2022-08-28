#!/bin/sh

if ! fipsmode=$(getarg fips) || [ $fipsmode = "0" ]; then
    rm -f -- /etc/modprobe.d/fips.conf >/dev/null 2>&1
else
    . /sbin/fips.sh
    fips_load_crypto || die "FIPS integrity test failed"
fi
