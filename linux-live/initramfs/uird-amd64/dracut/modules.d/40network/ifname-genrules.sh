#!/bin/sh

# if there are no ifname parameters, just use NAME=KERNEL
if ! getarg ifname= >/dev/null ; then
    return
fi

command -v parse_ifname_opts >/dev/null || . /lib/net-lib.sh

{
    for p in $(getargs ifname=); do
        parse_ifname_opts $p

        if [ -f /tmp/ifname-$ifname_mac ]; then
            read oldif < /tmp/ifname-$ifname_mac
        fi
        if [ -f /tmp/ifname-$ifname_if ]; then
            read oldmac < /tmp/ifname-$ifname_if
        fi
        if [ -n "$oldif" -a -n "$oldmac" -a "$oldif" = "$ifname_if" -a "$oldmac" = "$ifname_mac" ]; then
            # skip same ifname= declaration
            continue
        fi

        [ -n "$oldif" ] && warn "Multiple interface names specified for MAC $ifname_mac: $oldif"
        [ -n "$oldmac" ] && warn "Multiple MAC specified for $ifname_if: $oldmac"

        printf 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%s", ATTR{type}=="1", NAME="%s"\n' "$ifname_mac" "$ifname_if"
        echo $ifname_if > /tmp/ifname-$ifname_mac
        echo $ifname_mac > /tmp/ifname-$ifname_if
    done
} >> /etc/udev/rules.d/80-ifname.rules
