#!/bin/sh
#
# Preferred format:
#       root=iscsi:[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
#       [root=*] netroot=iscsi:[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
#
# Legacy formats:
#       [net]root=[iscsi] iscsiroot=[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
#       [net]root=[iscsi] iscsi_firmware
#
# root= takes precedence over netroot= if root=iscsi[...]
#

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)
if [ -z "$netroot" ]; then
    for nroot in $(getargs netroot=); do
        [ "${nroot%%:*}" = "iscsi" ] && break
    done
    if [ "${nroot%%:*}" = "iscsi" ]; then
        netroot="$nroot"
    else
        for nroot in $(getargs netroot=); do
            [ "${nroot%%:*}" = "dhcp" ] && break
        done
        netroot="$nroot"
    fi
fi
[ -z "$iscsiroot" ] && iscsiroot=$(getarg iscsiroot=)
[ -z "$iscsi_firmware" ] && getargbool 0 rd.iscsi.firmware -y iscsi_firmware && iscsi_firmware="1"

[ -n "$iscsiroot" ] && [ -n "$iscsi_firmware" ] && die "Mixing iscsiroot and iscsi_firmware is dangerous"

type write_fs_tab >/dev/null 2>&1 || . /lib/fs-lib.sh

# Root takes precedence over netroot
if [ "${root%%:*}" = "iscsi" ] ; then
    if [ -n "$netroot" ] ; then
        echo "Warning: root takes precedence over netroot. Ignoring netroot"
    fi
    netroot=$root
    # if root is not specified try to mount the whole iSCSI LUN
    printf 'ENV{DEVTYPE}!="partition", SYMLINK=="disk/by-path/*-iscsi-*-*", SYMLINK+="root"\n' >> /etc/udev/rules.d/99-iscsi-root.rules
    [ -n "$DRACUT_SYSTEMD" ] && systemctl is-active systemd-udevd && udevadm control --reload-rules
    root=/dev/root

    write_fs_tab /dev/root
fi

# If it's not empty or iscsi we don't continue
for nroot in $(getargs netroot); do
    [ "${nroot%%:*}" = "iscsi" ] || continue
    netroot="$nroot"
    break
done

# Root takes precedence over netroot
if [ "${root}" = "/dev/root" ] && getarg "netroot=dhcp" ; then
    # if root is not specified try to mount the whole iSCSI LUN
    printf 'ENV{DEVTYPE}!="partition", SYMLINK=="disk/by-path/*-iscsi-*-*", SYMLINK+="root"\n' >> /etc/udev/rules.d/99-iscsi-root.rules
    [ -n "$DRACUT_SYSTEMD" ] && systemctl is-active systemd-udevd && udevadm control --reload-rules
fi

if [ -n "$iscsiroot" ] ; then
    [ -z "$netroot" ]  && netroot=$root

    # @deprecated
    echo "Warning: Argument iscsiroot is deprecated and might be removed in a future"
    echo "release. See 'man dracut.kernel' for more information."

    # Accept iscsiroot argument?
    [ -z "$netroot" ] || [ "$netroot" = "iscsi" ] || \
        die "Argument iscsiroot only accepted for empty root= or [net]root=iscsi"

    # Override root with iscsiroot content?
    [ -z "$netroot" ] || [ "$netroot" = "iscsi" ] && netroot=iscsi:$iscsiroot
fi

# iscsi_firmware does not need argument checking
if [ -n "$iscsi_firmware" ]; then
    if [ "$root" != "dhcp" ] && [ "$netroot" != "dhcp" ]; then
        [ -z "$netroot" ] && netroot=iscsi:
    fi
    modprobe -b -q iscsi_boot_sysfs 2>/dev/null
    modprobe -b -q iscsi_ibft
    # if no ip= is given, but firmware
    echo "${DRACUT_SYSTEMD+systemctl is-active initrd-root-device.target || }[ -f '/tmp/iscsistarted-firmware' ]" > $hookdir/initqueue/finished/iscsi_started.sh
    initqueue --unique --online /sbin/iscsiroot online "iscsi:" "$NEWROOT"
    initqueue --unique --onetime --timeout /sbin/iscsiroot timeout "iscsi:" "$NEWROOT"
    initqueue --unique --onetime --settled /sbin/iscsiroot online "iscsi:" "'$NEWROOT'"
fi

# ISCSI actually supported?
if ! [ -e /sys/module/iscsi_tcp ]; then
    modprobe -b -q iscsi_tcp || die "iscsiroot requested but kernel/initrd does not support iscsi"
fi

modprobe --all -b -q qla4xxx cxgb3i cxgb4i bnx2i be2iscsi

if [ -n "$netroot" ] && [ "$root" != "/dev/root" ] && [ "$root" != "dhcp" ]; then
    if ! getargbool 1 rd.neednet >/dev/null || ! getarg "ip="; then
        initqueue --unique --onetime --settled /sbin/iscsiroot dummy "'$netroot'" "'$NEWROOT'"
    fi
fi

if arg=$(getarg rd.iscsi.initiator -d iscsi_initiator=) && [ -n "$arg" ] && ! [ -f /run/initiatorname.iscsi ] ; then
    iscsi_initiator=$arg
    echo "InitiatorName=$iscsi_initiator" > /run/initiatorname.iscsi
    ln -fs /run/initiatorname.iscsi /dev/.initiatorname.iscsi
    rm -f /etc/iscsi/initiatorname.iscsi
    mkdir -p /etc/iscsi
    ln -fs /run/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
    if [ -n "$DRACUT_SYSTEMD" ]; then
        systemctl try-restart iscsid
        # FIXME: iscsid is not yet ready, when the service is :-/
        sleep 1
    fi
fi

# If not given on the cmdline and initiator-name available via iBFT
if [ -z $iscsi_initiator ] && [ -f /sys/firmware/ibft/initiator/initiator-name ] && ! [ -f /tmp/iscsi_set_initiator ]; then
    iscsi_initiator=$(while read line || [ -n "$line" ]; do echo $line;done < /sys/firmware/ibft/initiator/initiator-name)
    if [ -n "$iscsi_initiator" ]; then
        echo "InitiatorName=$iscsi_initiator" > /run/initiatorname.iscsi
        rm -f /etc/iscsi/initiatorname.iscsi
        mkdir -p /etc/iscsi
        ln -fs /run/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
        > /tmp/iscsi_set_initiator
        if [ -n "$DRACUT_SYSTEMD" ]; then
            systemctl try-restart iscsid
            # FIXME: iscsid is not yet ready, when the service is :-/
            sleep 1
        fi
    fi
fi

if [ -z "$netroot" ] || ! [ "${netroot%%:*}" = "iscsi" ]; then
    return 1
fi

initqueue --unique --onetime --timeout /sbin/iscsiroot timeout "$netroot" "$NEWROOT"

for nroot in $(getargs netroot); do
    [ "${nroot%%:*}" = "iscsi" ] || continue
    type parse_iscsi_root >/dev/null 2>&1 || . /lib/net-lib.sh
    parse_iscsi_root "$nroot" || return 1
    netroot_enc=$(str_replace "$nroot" '/' '\2f')
    echo "${DRACUT_SYSTEMD+systemctl is-active initrd-root-device.target || }[ -f '/tmp/iscsistarted-$netroot_enc' ]" > $hookdir/initqueue/finished/iscsi_started.sh
done

# Done, all good!
rootok=1

# Shut up init error check
[ -z "$root" ] && root="iscsi"
