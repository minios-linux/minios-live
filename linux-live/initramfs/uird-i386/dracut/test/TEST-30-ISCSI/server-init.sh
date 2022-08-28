#!/bin/sh
exec </dev/console >/dev/console 2>&1
set -x
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
export TERM=linux
export PS1='server:\w\$ '
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

wait_for_if_link eth0 ens2
wait_for_if_link eth1 ens3

ip addr add 127.0.0.1/8 dev lo
ip link set lo up
ip link set dev eth0 name ens2
ip addr add 192.168.50.1/24 dev ens2
ip link set ens2 up
ip link set dev eth1 name ens3
ip addr add 192.168.51.1/24 dev ens3
ip link set ens3 up
>/var/lib/dhcpd/dhcpd.leases
chmod 777 /var/lib/dhcpd/dhcpd.leases
dhcpd -d -cf /etc/dhcpd.conf -lf /var/lib/dhcpd/dhcpd.leases &

tgtd
tgtadm --lld iscsi --mode target --op new --tid 1 --targetname iqn.2009-06.dracut:target0
tgtadm --lld iscsi --mode target --op new --tid 2 --targetname iqn.2009-06.dracut:target1
tgtadm --lld iscsi --mode target --op new --tid 3 --targetname iqn.2009-06.dracut:target2
tgtadm --lld iscsi --mode logicalunit --op new --tid 1 --lun 1 -b /dev/sdb
tgtadm --lld iscsi --mode logicalunit --op new --tid 2 --lun 2 -b /dev/sdc
tgtadm --lld iscsi --mode logicalunit --op new --tid 3 --lun 3 -b /dev/sdd
tgtadm --lld iscsi --mode target --op bind --tid 1 -I 192.168.50.101
tgtadm --lld iscsi --mode target --op bind --tid 2 -I 192.168.51.101
tgtadm --lld iscsi --mode target --op bind --tid 3 -I 192.168.50.101


# Wait forever for the VM to die
while :; do
	echo "Serving iSCSI"
	[ -n "$(jobs -rp)" ] && echo > /dev/watchdog
	sleep 10
done
mount -n -o remount,ro /
poweroff -f
