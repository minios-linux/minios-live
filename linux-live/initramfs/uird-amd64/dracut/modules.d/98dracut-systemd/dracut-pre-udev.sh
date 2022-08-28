#!/bin/sh
export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2>/dev/null
fi
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-udev" '1:shortmem' '2+:mem' '3+:slab'
# pre pivot scripts are sourced just before we doing cleanup and switch over
# to the new root.
getarg 'rd.break=pre-udev' 'rdbreak=pre-udev' && emergency_shell -n pre-udev "Break pre-udev"
source_hook pre-udev

_modprobe_d=/etc/modprobe.d
if [ -d /usr/lib/modprobe.d ] ; then
    _modprobe_d=/usr/lib/modprobe.d
elif [ -d /lib/modprobe.d ] ; then
    _modprobe_d=/lib/modprobe.d
elif [ ! -d $_modprobe_d ] ; then
    mkdir -p $_modprobe_d
fi

for i in $(getargs rd.driver.pre -d rdloaddriver=); do
    (
        IFS=,
        for p in $i; do
            modprobe $p 2>&1 | vinfo
        done
    )
done


[ -d /etc/modprobe.d ] || mkdir -p /etc/modprobe.d

for i in $(getargs rd.driver.blacklist -d rdblacklist=); do
    (
        IFS=,
        for p in $i; do
            echo "blacklist $p" >>  $_modprobe_d/initramfsblacklist.conf
        done
    )
done

for p in $(getargs rd.driver.post -d rdinsmodpost=); do
    echo "blacklist $p" >>  $_modprobe_d/initramfsblacklist.conf
    _do_insmodpost=1
done

[ -n "$_do_insmodpost" ] && initqueue --settled --unique --onetime insmodpost.sh
unset _do_insmodpost _modprobe_d
unset i

export -p > /dracut-state.sh
exit 0
