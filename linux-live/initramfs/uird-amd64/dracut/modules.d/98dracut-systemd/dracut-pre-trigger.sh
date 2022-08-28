#!/bin/sh

export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2>/dev/null
fi
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-trigger" '1:shortmem' '2+:mem' '3+:slab' '4+:komem'

source_hook pre-trigger

getarg 'rd.break=pre-trigger' 'rdbreak=pre-trigger' && emergency_shell -n pre-trigger "Break pre-trigger"

udevadm control --reload >/dev/null 2>&1 || :

export -p > /dracut-state.sh

exit 0
