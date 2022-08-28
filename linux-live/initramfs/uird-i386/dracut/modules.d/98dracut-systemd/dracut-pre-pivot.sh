#!/bin/sh

export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2>/dev/null
fi
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-pivot" '1:shortmem' '2+:mem' '3+:slab' '4+:komem'
# pre pivot scripts are sourced just before we doing cleanup and switch over
# to the new root.
getarg 'rd.break=pre-pivot' 'rdbreak=pre-pivot' && emergency_shell -n pre-pivot "Break pre-pivot"
source_hook pre-pivot

cleanup_trace_mem
# pre pivot cleanup scripts are sourced just before we switch over to the new root.
getarg 'rd.break=cleanup' 'rdbreak=cleanup' && emergency_shell -n cleanup "Break cleanup"
source_hook cleanup

_bv=$(getarg rd.break -d rdbreak) && [ -z "$_bv" ] &&
    emergency_shell -n switch_root "Break before switch_root"
unset _bv

# remove helper symlink
[ -h /dev/root ] && rm -f -- /dev/root
[ -h /dev/nfs ] && rm -f -- /dev/nfs

exit 0
