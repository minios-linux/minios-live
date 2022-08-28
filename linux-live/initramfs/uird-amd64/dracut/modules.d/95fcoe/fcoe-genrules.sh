#!/bin/sh

# We use (fcoe_interface or fcoe_mac) and fcoe_dcb as set by parse-fcoe.sh
# If neither mac nor interface are set we don't continue
[ -z "$fcoe_interface" -a -z "$fcoe_mac" ] && return

# Write udev rules
{
    if [ -n "$fcoe_mac" ] ; then
        printf 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="%s", RUN+="/sbin/initqueue --onetime --unique --name fcoe-up-$name /sbin/fcoe-up $name %s %s"\n' "$fcoe_mac" "$fcoe_dcb" "$fcoe_mode"
        printf 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="%s", RUN+="/sbin/initqueue --onetime --timeout --unique --name fcoe-timeout-$name /sbin/fcoe-up $name %s %s"\n' "$fcoe_mac" "$fcoe_dcb" "$fcoe_mode"
    else
        printf 'ACTION=="add", SUBSYSTEM=="net", NAME=="%s", RUN+="/sbin/initqueue --onetime --unique --name fcoe-up-$name /sbin/fcoe-up $name %s %s"\n' "$fcoe_interface" "$fcoe_dcb" "$fcoe_mode"
        printf 'ACTION=="add", SUBSYSTEM=="net", NAME=="%s", RUN+="/sbin/initqueue --onetime --timeout --unique --name fcoe-timeout-$name /sbin/fcoe-up $name %s %s"\n' "$fcoe_interface" "$fcoe_dcb" "$fcoe_mode"
    fi
} >> /etc/udev/rules.d/92-fcoe.rules
