#!/bin/sh

if ! getargbool 1 biosdevname; then
    info "biosdevname=0: removing biosdevname network renaming"
    udevproperty UDEV_BIOSDEVNAME=
    rm -f -- /etc/udev/rules.d/71-biosdevname.rules
else
    info "biosdevname=1: activating biosdevname network renaming"
    udevproperty UDEV_BIOSDEVNAME=1
fi

