#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

mkdir -m 0755 -p /run/initramfs/state/etc/sysconfig/network-scripts

function cms_write_config()
{
    . /tmp/cms.conf
    SUBCHANNELS="$(echo $SUBCHANNELS | sed 'y/ABCDEF/abcdef/')"
    OLDIFS=$IFS
    IFS=,
    read -a subch_array <<< "indexzero,$SUBCHANNELS"
    IFS=$OLDIFS
    devbusid=${subch_array[1]}
    if [ "$NETTYPE" = "ctc" ]; then
	driver="ctcm"
    else
	driver=$NETTYPE
    fi

    DEVICE=$(cd /sys/devices/${driver}/$devbusid/net/ && set -- * && [ "$1" != "*" ] && echo $1)

    uuid=$(cat /proc/sys/kernel/random/uuid)

    IFCFGFILE=/run/initramfs/state/etc/sysconfig/network-scripts/ifcfg-$DEVICE

    strglobin "$IPADDR" '*:*:*' && ipv6=1

# to please NetworkManager on startup in loader before loader reconfigures net
    cat > /etc/sysconfig/network << EOF
HOSTNAME=$HOSTNAME
EOF
    echo "$HOSTNAME" > /etc/hostname
    if [ "$ipv6" ]; then
	echo "NETWORKING_IPV6=yes" >> /etc/sysconfig/network
    else
	echo "NETWORKING=yes" >> /etc/sysconfig/network
    fi

    cat > $IFCFGFILE << EOF
DEVICE=$DEVICE
UUID=$uuid
ONBOOT=yes
BOOTPROTO=static
MTU=$MTU
SUBCHANNELS=$SUBCHANNELS
EOF
    if [ "$ipv6" ]; then
	cat >> $IFCFGFILE << EOF
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6ADDR=$IPADDR/$NETMASK
IPV6_DEFAULTGW=$GATEWAY
EOF
    else
	cat >> $IFCFGFILE << EOF
IPADDR=$IPADDR
NETMASK=$NETMASK
BROADCAST=$BROADCAST
GATEWAY=$GATEWAY
EOF
    fi
    if [ "$ipv6" ]; then
	DNS1=$(set -- ${DNS/,/ }; echo $1)
	DNS2=$(set -- ${DNS/,/ }; echo $2)
    else
	DNS1=$(set -- ${DNS/:/ }; echo $1)
	DNS2=$(set -- ${DNS/:/ }; echo $2)
    fi
# real DNS config for NetworkManager to generate /etc/resolv.conf
    [ "$DNS1" != "" ] && echo "DNS1=$DNS1" >> $IFCFGFILE
    [ "$DNS2" != "" ] && echo "DNS2=$DNS2" >> $IFCFGFILE
# just to please loader's readNetInfo && writeEnabledNetInfo
# which eats DNS1,DNS2,... and generates it themselves based on DNS
    if [ "$ipv6" ]; then
	[ "$DNS" != "" ] && echo "DNS=\"$DNS\"" >> $IFCFGFILE
    else
	[ "$DNS" != "" ] && echo "DNS=\"${DNS/:/,}\"" >> $IFCFGFILE
    fi
# colons in SEARCHDNS already replaced with spaces above for /etc/resolv.conf
    [ "$SEARCHDNS" != "" ] && echo "DOMAIN=\"$SEARCHDNS\"" >> $IFCFGFILE
    [ "$NETTYPE" != "" ] && echo "NETTYPE=$NETTYPE" >> $IFCFGFILE
    [ "$PEERID" != "" ] && echo "PEERID=$PEERID" >> $IFCFGFILE
    [ "$PORTNAME" != "" ] && echo "PORTNAME=$PORTNAME" >> $IFCFGFILE
    [ "$CTCPROT" != "" ] && echo "CTCPROT=$CTCPROT" >> $IFCFGFILE
    [ "$MACADDR" != "" ] && echo "MACADDR=$MACADDR" >> $IFCFGFILE
    optstr=""
    for option in LAYER2 PORTNO; do
	[ -z "${!option}" ] && continue
	[ -n "$optstr" ] && optstr=${optstr}" "
	optstr=${optstr}$(echo ${option} | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')"="${!option}
    done
# write single quotes since network.py removes double quotes but we need quotes
    echo "OPTIONS='$optstr'" >> $IFCFGFILE
    unset option
    unset optstr
    unset DNS1
    unset DNS2
    echo "files /etc/sysconfig/network-scripts" >> /run/initramfs/rwtab
    echo "files /var/lib/dhclient" >> /run/initramfs/rwtab
}

[ -f /tmp/cms.conf ] && cms_write_config
