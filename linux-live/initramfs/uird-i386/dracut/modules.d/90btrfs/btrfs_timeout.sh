#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

info "Scanning for all btrfs devices"
/sbin/btrfs device scan >/dev/null 2>&1
