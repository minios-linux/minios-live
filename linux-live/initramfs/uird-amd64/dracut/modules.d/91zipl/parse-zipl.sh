#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

zipl_arg=$(getarg rd.zipl)

if [ -n "$zipl_arg" ] ; then
    case "$zipl_arg" in
    LABEL=*) \
        zipl_env="ENV{ID_FS_LABEL}"
        zipl_val=${zipl_arg#LABEL=}
        zipl_arg="/dev/disk/by-label/${zipl_val}"
        ;;
    UUID=*) \
        zipl_env="ENV{ID_FS_UUID}"
        zipl_val=${zipl_arg#UUID=}
        zipl_arg="/dev/disk/by-uuid/${zipl_val}"
        ;;
    /dev/mapper/*) \
        zipl_env="ENV{DM_NAME}"
        zipl_val=${zipl_arg#/dev/mapper/}
        ;;
    /dev/disk/by-*) \
        zipl_env="SYMLINK"
        zipl_val=${zipl_arg#/dev/}
        ;;
    /dev/*) \
        zipl_env="KERNEL"
        zipl_val=${zipl_arg}
        ;;
    esac
    if [ "$zipl_env" ] ; then
        {
            printf 'ACTION=="add|change", SUBSYSTEM=="block", %s=="%s", RUN+="/sbin/initqueue --settled --onetime --unique --name install_zipl_cmdline /sbin/install_zipl_cmdline.sh %s"\n' \
                ${zipl_env} ${zipl_val} ${zipl_arg}
            echo "[ -f /tmp/install.zipl.cmdline-done ]" >$hookdir/initqueue/finished/wait-zipl-conf.sh
        } >> /etc/udev/rules.d/99zipl-conf.rules
        cat /etc/udev/rules.d/99zipl-conf.rules
    fi
    wait_for_dev -n "$zipl_arg"
fi
