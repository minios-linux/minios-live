#!/bin/sh

if [ -n "$netroot" ] || [ -e /tmp/net.ifaces ]; then
    echo rd.neednet >> /etc/cmdline.d/35-neednet.conf
fi

/usr/libexec/nm-initrd-generator -- $(getcmdline)
