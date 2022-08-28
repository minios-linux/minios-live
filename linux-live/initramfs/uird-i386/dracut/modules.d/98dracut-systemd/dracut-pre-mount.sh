#!/bin/sh

export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2>/dev/null
fi
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-mount" '1:shortmem' '2+:mem' '3+:slab' '4+:komem'
# pre pivot scripts are sourced just before we doing cleanup and switch over
# to the new root.
getarg 'rd.break=pre-mount' 'rdbreak=pre-mount' && emergency_shell -n pre-mount "Break pre-mount"
source_hook pre-mount

export -p > /dracut-state.sh

exit 0
