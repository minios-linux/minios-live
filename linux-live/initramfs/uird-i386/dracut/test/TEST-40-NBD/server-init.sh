#!/bin/sh
exec </dev/console >/dev/console 2>&1
set -x
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
export TERM=linux
export PS1='nbdtest-server:\w\$ '
stty sane
echo "made it to the rootfs!"
echo server > /proc/sys/kernel/hostname

wait_for_if_link() {
    local cnt=0
    local li
    while [ $cnt -lt 600 ]; do
        li=$(ip -o link show dev $1 2>/dev/null)
	[ -n "$li" ] && return 0
        if [[ $2 ]]; then
	    li=$(ip -o link show dev $2 2>/dev/null)
	    [ -n "$li" ] && return 0
        fi
        sleep 0.1
        cnt=$(($cnt+1))
    done
    return 1
}

wait_for_if_up() {
    local cnt=0
    local li
    while [ $cnt -lt 200 ]; do
        li=$(ip -o link show up dev $1)
        [ -n "$li" ] && return 0
        sleep 0.1
        cnt=$(($cnt+1))
    done
    return 1
}

wait_for_route_ok() {
    local cnt=0
    while [ $cnt -lt 200 ]; do
        li=$(ip route show)
        [ -n "$li" ] && [ -z "${li##*$1*}" ] && return 0
        sleep 0.1
        cnt=$(($cnt+1))
    done
    return 1
}

linkup() {
    wait_for_if_link $1 2>/dev/null\
     && ip link set $1 up 2>/dev/null\
     && wait_for_if_up $1 2>/dev/null
}

wait_for_if_link eth0 ens3

ip addr add 127.0.0.1/8 dev lo
ip link set lo up
ip link set dev eth0 name ens3
ip addr add 192.168.50.1/24 dev ens3
linkup ens3

modprobe af_packet
nbd-server
>/var/lib/dhcpd/dhcpd.leases
chmod 777 /var/lib/dhcpd/dhcpd.leases
dhcpd -d -cf /etc/dhcpd.conf -lf /var/lib/dhcpd/dhcpd.leases &
echo "Serving NBD disks"
while :; do
	[ -n "$(jobs -rp)" ] && echo > /dev/watchdog
	sleep 10
done
mount -n -o remount,ro /
poweroff -f
