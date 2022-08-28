#!/bin/sh
exec </dev/console >/dev/console 2>&1
set -x
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
export TERM=linux
export PS1='nfstest-server:\w\$ '
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

wait_for_if_link eth0 ens2
wait_for_if_link eth1 ens3
wait_for_if_link eth2 ens4
wait_for_if_link eth3 ens5

modprobe --all -b -q 8021q ipvlan macvlan
>/dev/watchdog
ip addr add 127.0.0.1/8 dev lo
linkup lo
ip link set dev eth0 name ens2
ip addr add 192.168.50.1/24 dev ens2
linkup ens2
>/dev/watchdog
ip link set dev eth1 name ens3
ip link add dev ens3.1 link ens3 type vlan id 1
ip link add dev ens3.2 link ens3 type vlan id 2
ip link add dev ens3.3 link ens3 type vlan id 3
ip link add dev ens3.4 link ens3 type vlan id 4
ip addr add 192.168.54.1/24 dev ens3.1
ip addr add 192.168.55.1/24 dev ens3.2
ip addr add 192.168.56.1/24 dev ens3.3
ip addr add 192.168.57.1/24 dev ens3.4
linkup ens3
ip link set dev ens3.1 up
ip link set dev ens3.2 up
ip link set dev ens3.3 up
ip link set dev ens3.4 up
ip link set dev eth2 name ens4
ip addr add 192.168.51.1/24 dev ens4
linkup ens4
ip link set dev eth3 name ens5
linkup ens5
>/dev/watchdog
modprobe af_packet
> /dev/watchdog
modprobe sunrpc
>/dev/watchdog
mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs
>/dev/watchdog
[ -x /sbin/portmap ] && portmap
>/dev/watchdog
mkdir -p /run/rpcbind
[ -x /sbin/rpcbind ] && rpcbind
>/dev/watchdog
modprobe nfsd
>/dev/watchdog
mount -t nfsd nfsd /proc/fs/nfsd
>/dev/watchdog
exportfs -r
>/dev/watchdog
rpc.nfsd
>/dev/watchdog
rpc.mountd
>/dev/watchdog
rpc.idmapd -S
>/dev/watchdog
exportfs -r
>/dev/watchdog
>/var/lib/dhcpd/dhcpd.leases
>/dev/watchdog
chmod 777 /var/lib/dhcpd/dhcpd.leases
>/dev/watchdog
dhcpd -cf /etc/dhcpd.conf -lf /var/lib/dhcpd/dhcpd.leases ens2 ens4
#echo -n 'V' > /dev/watchdog
#sh -i
#tcpdump -i ens2
# Wait forever for the VM to die
echo "Serving"
while :; do
	sleep 10
	>/dev/watchdog
done
mount -n -o remount,ro /
poweroff -f
