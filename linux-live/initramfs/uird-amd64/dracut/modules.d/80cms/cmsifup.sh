#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

DEVICE=$1

. /tmp/cms.conf

strglobin "$IPADDR" '*:*:*' && ipv6=1

if [ "$ipv6" ] && ! str_starts "$IPADDR" "["; then
    IPADDR="[$IPADDR]"
fi

if [ "$ipv6" ] && ! str_starts "$GATEWAY" "["; then
    GATEWAY="[$GATEWAY]"
fi

if [ "$ipv6" ]; then
    DNS1=$(set -- ${DNS/,/ }; echo $1)
    DNS2=$(set -- ${DNS/,/ }; echo $2)
else
    DNS1=$(set -- ${DNS/:/ }; echo $1)
    DNS2=$(set -- ${DNS/:/ }; echo $2)
fi

{
    echo "ip=$IPADDR::$GATEWAY:$NETMASK:$HOSTNAME:$DEVICE:none:$MTU:$MACADDR"
    for i in $DNS1 $DNS2; do
	echo "nameserver=$i"
    done
} > /etc/cmdline.d/80-cms.conf

[ -e "/tmp/net.ifaces" ] && read IFACES < /tmp/net.ifaces
IFACES="$IFACES $DEVICE"
echo "$IFACES" >> /tmp/net.ifaces

exec ifup "$DEVICE"
