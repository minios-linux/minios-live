#!/bin/sh

[ -f /lib/dracut-lib.sh ] && . /lib/dracut-lib.sh

pid=$(pidof stratisd-init)
[ -n "$pid" ] && kill ${pid}
