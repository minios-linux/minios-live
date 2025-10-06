#!/bin/sh
# MiniOS mount_root hook for dracut

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

if getarg boot=live >/dev/null || getarg from= >/dev/null; then
    mount_root() {
        . /minios-init
    }
    mount_root
fi
