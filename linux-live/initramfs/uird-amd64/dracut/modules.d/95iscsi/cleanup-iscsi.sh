#!/bin/sh

if [ -z "${DRACUT_SYSTEMD}" ] && ( [ -e /sys/module/bnx2i ] || [ -e /sys/module/qedi ] ) ; then
      killproc iscsiuio
fi
