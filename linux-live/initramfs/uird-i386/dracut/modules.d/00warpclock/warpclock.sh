#!/bin/sh

if test -e /etc/adjtime ; then
    while read line ; do
	if test "$line" = LOCAL ; then
	    hwclock --systz
	fi
    done < /etc/adjtime
fi
