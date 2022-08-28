#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# root=uird:<mountpoint>:<base_from>:<data_from>[,<options>]
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

uird_to_var() {
	local params

	params=${1##uird:}
	params=${params%%,*}
	base_from=${params%%:*}
	data_from=${params##*:}

	uird_options=${1#*,}
}

#Don't continue if root is ok
[ -n "$rootok" ] && return

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)

# If it's not magos we don't continue
#[ "${root%%:*}" = "uird" ] || return

# Check required arguments
#uird_to_var $root

#[ -n "$base_from" ] || die "Argument uirdroot needs base_from param"
#[ -n "$data_from" ] || die "Argument uirdroot needs data_from param"

# Done, all good!
root=1
rootok=1
