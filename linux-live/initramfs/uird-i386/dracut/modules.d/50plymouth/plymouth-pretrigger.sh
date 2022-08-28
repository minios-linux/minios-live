#!/bin/sh

if type plymouthd >/dev/null 2>&1 && [ -z "$DRACUT_SYSTEMD" ]; then
    if getargbool 1 plymouth.enable && getargbool 1 rd.plymouth -d -n rd_NO_PLYMOUTH; then
        # first trigger graphics subsystem
        udevadm trigger --action=add --attr-match=class=0x030000 >/dev/null 2>&1
        # first trigger graphics and tty subsystem
        udevadm trigger --action=add \
            --subsystem-match=graphics \
            --subsystem-match=drm \
            --subsystem-match=tty \
            --subsystem-match=acpi \
            >/dev/null 2>&1

        udevadm settle --timeout=180 2>&1 | vinfo

        info "Starting plymouth daemon"
        mkdir -m 0755 /run/plymouth
        read consoledev rest < /sys/class/tty/console/active
        consoledev=${consoledev:-tty0}
        [ -x /lib/udev/console_init -a -e "/dev/$consoledev" ] && /lib/udev/console_init "/dev/$consoledev"
        plymouthd --attach-to-session --pid-file /run/plymouth/pid
        plymouth --show-splash 2>&1 | vinfo
        # reset tty after plymouth messed with it
        [ -x /lib/udev/console_init -a -e "/dev/$consoledev" ] && /lib/udev/console_init "/dev/$consoledev"
    fi
fi
