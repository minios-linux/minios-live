#!/bin/sh
for dasd_arg in $(getargs rd.dasd= -d rd_DASD= DASD=); do
    (
        local OLDIFS="$IFS"
        IFS=","
        set -- $dasd_arg
        IFS="$OLDIFS"
        echo "$@" | normalize_dasd_arg >> /etc/dasd.conf
    )
done
