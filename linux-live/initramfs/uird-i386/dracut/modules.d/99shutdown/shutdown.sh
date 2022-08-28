#!/bin/sh
#
# Licensed under the GPLv2
#
# Copyright 2011, Red Hat, Inc.
# Harald Hoyer <harald@redhat.com>
ACTION="$1"

# Before trying to use /dev/console, verify that it exists,
# and that it can actually be used. When console=null is used,
# echo will fail. We do the check in a subshell, because otherwise
# the process will be killed when when running as PID 1.
[ -w /dev/console ] && \
    ( echo </dev/console &>/dev/null ) && \
    exec </dev/console >>/dev/console 2>>/dev/console

export TERM=linux
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
. /lib/dracut-lib.sh

if [ "$(stat -c '%T' -f /)" = "tmpfs" ]; then
    mount -o remount,rw /
fi

mkdir /oldsys
for i in sys proc run dev; do
    mkdir /oldsys/$i
    mount --move /oldroot/$i /oldsys/$i
done

# if "kexec" was installed after creating the initramfs, we try to copy it from the real root
# libz normally is pulled in via kmod/modprobe and udevadm
if [ "$ACTION" = "kexec" ] && ! command -v kexec >/dev/null 2>&1; then
    for p in /usr/sbin /usr/bin /sbin /bin; do
        cp -a /oldroot/${p}/kexec $p >/dev/null 2>&1 && break
    done
    hash kexec
fi

trap "emergency_shell --shutdown shutdown Signal caught!" 0
getarg 'rd.break=pre-shutdown' && emergency_shell --shutdown pre-shutdown "Break before pre-shutdown"

source_hook pre-shutdown

warn "Killing all remaining processes"

killall_proc_mountpoint /oldroot || sleep 0.2

umount_a() {
    local _did_umount="n"
    while read a mp a || [ -n "$mp" ]; do
        if strstr "$mp" oldroot; then
            if umount "$mp"; then
                _did_umount="y"
                warn "Unmounted $mp."
            fi
        fi
    done </proc/mounts
    losetup -D
    [ "$_did_umount" = "y" ] && return 0
    return 1
}

_cnt=0
while [ $_cnt -le 40 ]; do
    umount_a 2>/dev/null || break
    _cnt=$(($_cnt+1))
done

[ $_cnt -ge 40 ] && umount_a

if strstr "$(cat /proc/mounts)" "/oldroot"; then
    warn "Cannot umount /oldroot"
    for _pid in /proc/*; do
        _pid=${_pid##/proc/}
        case $_pid in
            *[!0-9]*) continue;;
        esac
        [ $_pid -eq $$ ] && continue

        [ -e "/proc/$_pid/exe" ] || continue
        [ -e "/proc/$_pid/root" ] || continue

        if strstr "$(ls -l /proc/$_pid /proc/$_pid/fd 2>/dev/null)" "oldroot"; then
            warn "Blocking umount of /oldroot [$_pid] $(cat /proc/$_pid/cmdline)"
        else
            warn "Still running [$_pid] $(cat /proc/$_pid/cmdline)"
        fi

        ls -l "/proc/$_pid/exe" 2>&1 | vwarn
        ls -l "/proc/$_pid/fd" 2>&1 | vwarn
    done
fi

_check_shutdown() {
    local __f
    local __s=0
    for __f in $hookdir/shutdown/*.sh; do
        [ -e "$__f" ] || continue
        ( . "$__f" $1 )
        if [ $? -eq 0 ]; then
            rm -f -- $__f
        else
            __s=1
        fi
    done
    return $__s
}

_cnt=0
while [ $_cnt -le 40 ]; do
    _check_shutdown && break
    _cnt=$(($_cnt+1))
done
[ $_cnt -ge 40 ] && _check_shutdown final

getarg 'rd.break=shutdown' && emergency_shell --shutdown shutdown "Break before shutdown"

case "$ACTION" in
    reboot|poweroff|halt)
        $ACTION -f -n
        warn "$ACTION failed!"
        ;;
    kexec)
        kexec -e
        warn "$ACTION failed!"
        reboot -f -n
        ;;
    *)
        warn "Shutdown called with argument '$ACTION'. Rebooting!"
        reboot -f -n
        ;;
esac

emergency_shell --shutdown shutdown
