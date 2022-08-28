#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type ip_to_var >/dev/null 2>&1 || . /lib/net-lib.sh

# We already need a set netif here
netif=$interface

setup_interface() {
    ip=$new_ip_address
    mtu=$new_interface_mtu
    mask=$new_subnet_mask
    bcast=$new_broadcast_address
    gw=${new_routers%%,*}
    domain=$new_domain_name
    search=$(printf -- "$new_domain_search")
    namesrv=$new_domain_name_servers
    hostname=$new_host_name
    [ -n "$new_dhcp_lease_time" ] && lease_time=$new_dhcp_lease_time
    [ -n "$new_max_life" ] && lease_time=$new_max_life
    preferred_lft=$lease_time
    [ -n "$new_preferred_life" ] && preferred_lft=$new_preferred_life

    [ -f /tmp/net.$netif.override ] && . /tmp/net.$netif.override

    # Taken from debian dhclient-script:
    # The 576 MTU is only used for X.25 and dialup connections
    # where the admin wants low latency.  Such a low MTU can cause
    # problems with UDP traffic, among other things.  As such,
    # disallow MTUs from 576 and below by default, so that broken
    # MTUs are ignored, but higher stuff is allowed (1492, 1500, etc).
    if [ -n "$mtu" ] && [ $mtu -gt 576 ] ; then
        if ! ip link set $netif mtu $mtu ; then
            ip link set $netif down
            ip link set $netif mtu $mtu
            linkup $netif
        fi
    fi

    ip addr add $ip${mask:+/$mask} ${bcast:+broadcast $bcast} dev $netif \
        ${lease_time:+valid_lft $lease_time} \
        ${preferred_lft:+preferred_lft ${preferred_lft}}

    if [ -n "$gw" ] ; then
        if [ "$mask" = "255.255.255.255" ] ; then
            # point-to-point connection => set explicit route to gateway
            echo ip route add $gw dev $netif > /tmp/net.$netif.gw
        fi

        echo "$gw" | {
            IFS=' ' read -r main_gw other_gw
            echo ip route replace default via $main_gw dev $netif >> /tmp/net.$netif.gw
            if [ -n "$other_gw" ] ; then
                for g in $other_gw; do
                    echo ip route add default via $g dev $netif >> /tmp/net.$netif.gw
                done
            fi
        }
    fi

    if getargbool 1 rd.peerdns; then
        [ -n "${search}${domain}" ] && echo "search $search $domain" > /tmp/net.$netif.resolv.conf
        if  [ -n "$namesrv" ] ; then
            for s in $namesrv; do
                echo nameserver $s
            done
        fi >> /tmp/net.$netif.resolv.conf
    fi
    # Note: hostname can be fqdn OR short hostname, so chop off any
    # trailing domain name and explicity add any domain if set.
    [ -n "$hostname" ] && echo "echo ${hostname%.$domain}${domain:+.$domain} > /proc/sys/kernel/hostname" > /tmp/net.$netif.hostname
}

setup_interface6() {
    domain=$new_domain_name
    search=$(printf -- "$new_dhcp6_domain_search")
    namesrv=$new_dhcp6_name_servers
    hostname=$new_host_name
    [ -n "$new_dhcp_lease_time" ] && lease_time=$new_dhcp_lease_time
    [ -n "$new_max_life" ] && lease_time=$new_max_life
    preferred_lft=$lease_time
    [ -n "$new_preferred_life" ] && preferred_lft=$new_preferred_life

    [ -f /tmp/net.$netif.override ] && . /tmp/net.$netif.override

    ip -6 addr add ${new_ip6_address}/${new_ip6_prefixlen} \
        dev ${netif} scope global \
        ${lease_time:+valid_lft $lease_time} \
        ${preferred_lft:+preferred_lft ${preferred_lft}}

    if getargbool 1 rd.peerdns; then
        [ -n "${search}${domain}" ] && echo "search $search $domain" > /tmp/net.$netif.resolv.conf
        if  [ -n "$namesrv" ] ; then
            for s in $namesrv; do
                echo nameserver $s
            done
        fi >> /tmp/net.$netif.resolv.conf
    fi

    # Note: hostname can be fqdn OR short hostname, so chop off any
    # trailing domain name and explicity add any domain if set.
    [ -n "$hostname" ] && echo "echo ${hostname%.$domain}${domain:+.$domain} > /proc/sys/kernel/hostname" > /tmp/net.$netif.hostname
}

parse_option_121() {
    while [ $# -ne 0 ]; do
        mask="$1"
        shift

        # Is the destination a multicast group?
        if [ $1 -ge 224 -a $1 -lt 240 ]; then
            multicast=1
        else
            multicast=0
        fi

        # Parse the arguments into a CIDR net/mask string
        if [ $mask -gt 24 ]; then
            destination="$1.$2.$3.$4/$mask"
            shift; shift; shift; shift
        elif [ $mask -gt 16 ]; then
            destination="$1.$2.$3.0/$mask"
            shift; shift; shift
        elif [ $mask -gt 8 ]; then
            destination="$1.$2.0.0/$mask"
            shift; shift
        elif [ $mask -gt 0 ]; then
            destination="$1.0.0.0/$mask"
            shift
        else
            destination="0.0.0.0/$mask"
        fi

        # Read the gateway
        gateway="$1.$2.$3.$4"
        shift; shift; shift; shift

        # Multicast routing on Linux
        #  - If you set a next-hop address for a multicast group, this breaks with Cisco switches
        #  - If you simply leave it link-local and attach it to an interface, it works fine.
        if [ $multicast -eq 1 -o "$gateway" = "0.0.0.0" ]; then
            temp_result="$destination dev $interface"
        else
            temp_result="$destination via $gateway dev $interface"
        fi

        echo "/sbin/ip route replace $temp_result"
    done
}


case $reason in
    PREINIT)
        echo "dhcp: PREINIT $netif up"
        linkup $netif
        ;;

    PREINIT6)
        echo "dhcp: PREINIT6 $netif up"
        linkup $netif
        wait_for_ipv6_dad_link $netif
        ;;

    BOUND)
        echo "dhcp: BOND setting $netif"
        unset layer2
        if [ -f /sys/class/net/$netif/device/layer2 ]; then
            read layer2 < /sys/class/net/$netif/device/layer2
        fi
        if [ "$layer2" != "0" ]; then
            if command -v arping2 >/dev/null; then
                if arping2 -q -C 1 -c 2 -I $netif -0 $new_ip_address ; then
                    warn "Duplicate address detected for $new_ip_address while doing dhcp. retrying"
                    exit 1
                fi
            else
                if ! arping -f -q -D -c 2 -I $netif $new_ip_address ; then
                    warn "Duplicate address detected for $new_ip_address while doing dhcp. retrying"
                    exit 1
                fi
            fi
        fi
        unset layer2
        setup_interface
        set | while read line || [ -n "$line" ]; do
            [ "${line#new_}" = "$line" ] && continue
            echo "$line"
        done >/tmp/dhclient.$netif.dhcpopts

        {
            echo '. /lib/net-lib.sh'
            echo "setup_net $netif"
            if [ -n "$new_classless_static_routes" ]; then
                OLDIFS="$IFS"
                IFS=".$IFS"
                parse_option_121 $new_classless_static_routes
                IFS="$OLDIFS"
            fi
            echo "source_hook initqueue/online $netif"
            [ -e /tmp/net.$netif.manualup ] || echo "/sbin/netroot $netif"
            echo "rm -f -- $hookdir/initqueue/setup_net_$netif.sh"
        } > $hookdir/initqueue/setup_net_$netif.sh

        echo "[ -f /tmp/net.$netif.did-setup ]" > $hookdir/initqueue/finished/dhclient-$netif.sh
        >/tmp/net.$netif.up
        if [ -e /sys/class/net/${netif}/address ]; then
            > /tmp/net.$(cat /sys/class/net/${netif}/address).up
        fi

        ;;

    RENEW|REBIND)
        unset lease_time
        [ -n "$new_dhcp_lease_time" ] && lease_time=$new_dhcp_lease_time
        [ -n "$new_max_life" ] && lease_time=$new_max_life
        preferred_lft=$lease_time
        [ -n "$new_preferred_life" ] && preferred_lft=$new_preferred_life
        ip -4 addr change ${new_ip_address}/${new_subnet_mask} broadcast ${new_broadcast_address} dev ${interface} \
           ${lease_time:+valid_lft $lease_time} ${preferred_lft:+preferred_lft ${preferred_lft}} \
           >/dev/null 2>&1
        ;;

    BOUND6)
        echo "dhcp: BOND6 setting $netif"
        setup_interface6

        set | while read line || [ -n "$line" ]; do
            [ "${line#new_}" = "$line" ] && continue
            echo "$line"
        done >/tmp/dhclient.$netif.dhcpopts

        {
            echo '. /lib/net-lib.sh'
            echo "setup_net $netif"
            echo "source_hook initqueue/online $netif"
            [ -e /tmp/net.$netif.manualup ] || echo "/sbin/netroot $netif"
            echo "rm -f -- $hookdir/initqueue/setup_net_$netif.sh"
        } > $hookdir/initqueue/setup_net_$netif.sh

        echo "[ -f /tmp/net.$netif.did-setup ]" > $hookdir/initqueue/finished/dhclient-$netif.sh
        >/tmp/net.$netif.up
        if [ -e /sys/class/net/${netif}/address ]; then
            > /tmp/net.$(cat /sys/class/net/${netif}/address).up
        fi
        ;;

    RENEW6|REBIND6)
        unset lease_time
        [ -n "$new_dhcp_lease_time" ] && lease_time=$new_dhcp_lease_time
        [ -n "$new_max_life" ] && lease_time=$new_max_life
        preferred_lft=$lease_time
        [ -n "$new_preferred_life" ] && preferred_lft=$new_preferred_life
        ip -6 addr change ${new_ip6_address}/${new_ip6_prefixlen} dev ${interface} scope global \
           ${lease_time:+valid_lft $lease_time} ${preferred_lft:+preferred_lft ${preferred_lft}} \
           >/dev/null 2>&1
        ;;

    *) echo "dhcp: $reason";;
esac

exit 0
