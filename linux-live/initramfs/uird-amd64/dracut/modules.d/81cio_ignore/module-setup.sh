#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# called by dracut
check() {
# do not add this module by default
    local arch=${DRACUT_ARCH:-$(uname -m)}
    [ "$arch" = "s390" -o "$arch" = "s390x" ] || return 1
    return 0
}

cmdline() {
    local cio_accept

    if [ -e /boot/zipl/active_devices.txt ] ; then
        while read dev etc ; do
            [ "$dev" = "#" -o "$dev" = "" ] && continue;
            if [ -z "$cio_accept" ] ; then
                cio_accept="$dev"
            else
                cio_accept="${cio_accept},${dev}"
            fi
        done < /boot/zipl/active_devices.txt
    fi
    if [ -n "$cio_accept" ] ; then
	echo "rd.cio_accept=${cio_accept}"
    fi
}

# called by dracut
install() {
    if [[ $hostonly_cmdline == "yes" ]] ; then
        local _cio_accept=$(cmdline)
        [[ $_cio_accept ]] && printf "%s\n" "$_cio_accept" >> "${initdir}/etc/cmdline.d/01cio_accept.conf"
    fi

    inst_hook cmdline 20 "$moddir/parse-cio_accept.sh"
    inst_multiple cio_ignore
}
