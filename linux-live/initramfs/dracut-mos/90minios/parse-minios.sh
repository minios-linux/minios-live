#!/bin/sh
# MiniOS command line parser for dracut

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

# Don't continue if root is already ok
[ -n "$rootok" ] && return

# Check if this is a MiniOS boot
if getarg boot=live >/dev/null || getarg from= >/dev/null; then
    info "MiniOS boot detected"

    # Tell dracut we'll handle the root
    root=1
    rootok=1
    wait_for_dev=0
fi
