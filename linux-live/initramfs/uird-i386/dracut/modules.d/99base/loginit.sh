#!/bin/sh

# turn off debugging
set +x

QUIET=$1

printf -- "$$" > /run/initramfs/loginit.pid

[ -e /dev/kmsg ] && exec 5>/dev/kmsg || exec 5>/dev/null
exec 6>/run/initramfs/init.log

while read line || [ -n "$line" ]; do
    if [ "$line" = "DRACUT_LOG_END" ]; then
        rm -f -- /run/initramfs/loginit.pipe
        exit 0
    fi
    echo "<31>dracut: $line" >&5
    # if "quiet" is specified we output to /dev/console
    [ -n "$QUIET" ] || echo "dracut: $line"
    echo "$line" >&6
done
