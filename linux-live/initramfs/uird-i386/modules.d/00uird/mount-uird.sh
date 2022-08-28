#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

mount_root() {

	#    /usr/bin/busybox --install
	. /uird-init

}

mount_root

#if [ -n "$root" -a -z "${root%%uird:*}" ]; then
#    mount_root
#fi
