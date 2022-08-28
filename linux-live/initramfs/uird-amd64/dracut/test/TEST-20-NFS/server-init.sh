#!/bin/sh
exec </dev/console >/dev/console 2>&1
set -x
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
export TERM=linux
export PS1='nfstest-server:\w\$ '
echo > /dev/watchdog
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

ip addr add 127.0.0.1/8 dev lo
ip link set lo up
ip link set dev eth0 name ens2
ip addr add 192.168.50.1/24 dev ens2
ip addr add 192.168.50.2/24 dev ens2
ip addr add 192.168.50.3/24 dev ens2
linkup ens2

echo > /dev/watchdog
modprobe af_packet
echo > /dev/watchdog
mount --bind /nfs/client /nfs/nfs3-5
echo > /dev/watchdog
mount --bind /nfs/client /nfs/ip/192.168.50.101
echo > /dev/watchdog
mount --bind /nfs/client /nfs/tftpboot/nfs4-5
echo > /dev/watchdog
modprobe sunrpc
echo > /dev/watchdog
mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs
echo > /dev/watchdog
[ -x /sbin/portmap ] && portmap
echo > /dev/watchdog
mkdir -p /run/rpcbind
[ -x /sbin/rpcbind ] && rpcbind
echo > /dev/watchdog
modprobe nfsd
echo > /dev/watchdog
mount -t nfsd nfsd /proc/fs/nfsd
echo > /dev/watchdog
exportfs -r
echo > /dev/watchdog
rpc.nfsd
echo > /dev/watchdog
rpc.mountd
echo > /dev/watchdog
rpc.idmapd
echo > /dev/watchdog
exportfs -r
echo > /dev/watchdog
mkdir -p /var/lib/dhcpd
>/var/lib/dhcpd/dhcpd.leases
echo > /dev/watchdog
chmod 777 /var/lib/dhcpd/dhcpd.leases
echo > /dev/watchdog
rm -f /var/run/dhcpd.pid
dhcpd -d -cf /etc/dhcpd.conf -lf /var/lib/dhcpd/dhcpd.leases &
echo "Serving NFS mounts"
while :; do
	[ -n "$(jobs -rp)" ] && echo > /dev/watchdog
	sleep 10
done
mount -n -o remount,ro /
poweroff -f
