#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

for md in /dev/md[0-9_]*; do
    [ -b "$md" ] || continue
    need_shutdown
    break
done
