#!/bin/sh

. /lib/dracut-lib.sh

for modlist in $(getargs rd.driver.post -d rdinsmodpost=); do
    (
        IFS=,
        for m in $modlist; do
            modprobe $m
        done
    )
done
