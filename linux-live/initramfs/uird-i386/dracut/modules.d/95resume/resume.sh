#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ -s /.resume -a -b "$resume" ] && {
    # First try user level resume; it offers splash etc
    case "$splash" in
        quiet )
            a_splash="-P splash=y"
        ;;
        * )
            a_splash="-P splash=n"
        ;;
    esac
    [ -x "$(command -v resume)" ] && command resume $a_splash "$resume"

    # parsing the output of ls is Bad, but until there is a better way...
    ls -lH "$resume" | (
        read x x x x maj min x;
        echo "${maj%,}:$min"> /sys/power/resume)
    >/.resume
}
