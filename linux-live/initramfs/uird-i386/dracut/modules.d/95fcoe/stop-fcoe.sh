#!/bin/bash

for f in /sys/bus/fcoe/devices/ctlr_* ; do
    [ -e $f ] || continue
    echo 0 > $f/enabled
done
