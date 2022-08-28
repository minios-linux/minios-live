#!/bin/sh
exec >/dev/console 2>&1
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
strstr() { [ "${1#*$2*}" != "$1" ]; }
CMDLINE=$(while read line; do echo $line;done < /proc/cmdline)
export TERM=linux
export PS1='initramfs-test:\w\$ '
stty sane
echo "made it to the rootfs! Powering down."

(
    echo OK
    ip -o -4 address show scope global | while read n if rest; do echo $if;done | sort
    for i in /run/initramfs/state/etc/sysconfig/network-scripts/ifcfg-*; do
	  echo $i
	  grep -v 'UUID=' $i
    done
    echo EOF
) | dd oflag=direct,dsync of=/dev/sda

strstr "$CMDLINE" "rd.shell" && sh -i
poweroff -f
