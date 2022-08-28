#!/bin/sh

if [ -e /etc/multipath.conf ]; then
    HARD=""
    while pidof multipathd >/dev/null 2>&1; do
        for pid in $(pidof multipathd); do
            kill $HARD $pid >/dev/null 2>&1
        done
        HARD="-9"
    done
fi

