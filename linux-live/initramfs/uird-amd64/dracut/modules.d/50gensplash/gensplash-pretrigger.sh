#!/bin/sh

if getargbool 1 rd.splash -d -n rd_NO_SPLASH; then
    info "Starting Gentoo Splash"

    [ -x /lib/udev/console_init ] && /lib/udev/console_init /dev/tty0
    CDROOT=0
    . /lib/gensplash-lib.sh
    splash init
    [ -x /lib/udev/console_init ] && /lib/udev/console_init /dev/tty0
fi
