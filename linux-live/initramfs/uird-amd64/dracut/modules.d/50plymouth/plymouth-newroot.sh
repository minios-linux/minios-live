#!/bin/sh

if type plymouth >/dev/null 2>&1 && [ -z "$DRACUT_SYSTEMD" ]; then
    plymouth --newroot=$NEWROOT
fi
