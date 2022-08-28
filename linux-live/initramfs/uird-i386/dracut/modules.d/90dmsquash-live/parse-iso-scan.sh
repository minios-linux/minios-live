#!/bin/sh
# live images are specified with
# root=live:backingdev

isofile=$(getarg iso-scan/filename)

if [ -n "$isofile" ]; then
    /sbin/initqueue --settled --unique /sbin/iso-scan "$isofile"
fi
