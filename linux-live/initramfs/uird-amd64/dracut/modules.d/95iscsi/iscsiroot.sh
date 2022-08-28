#!/bin/sh
#
# This implementation is incomplete: Discovery mode is not implemented and
# the argument handling doesn't follow currently agreed formats. This is mainly
# because rfc4173 does not say anything about iscsi_initiator but open-iscsi's
# iscsistart needs this.
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type parse_iscsi_root >/dev/null 2>&1 || . /lib/net-lib.sh
type write_fs_tab >/dev/null 2>&1 || . /lib/fs-lib.sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Huh? Empty $1?
[ -z "$1" ] && exit 1

# Huh? Empty $2?
[ -z "$2" ] && exit 1

# Huh? Empty $3? This isn't really necessary, since NEWROOT isn't
# used here. But let's be consistent
[ -z "$3" ] && exit 1

# root is in the form root=iscsi:[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
netif="$1"
iroot="$2"

# If it's not iscsi we don't continue
[ "${iroot%%:*}" = "iscsi" ] || exit 1

iroot=${iroot#iscsi}
iroot=${iroot#:}

# XXX modprobe crc32c should go in the cmdline parser, but I haven't yet
# figured out a way how to check whether this is built-in or not
modprobe crc32c 2>/dev/null

# start iscsiuio if needed
if [ -z "${DRACUT_SYSTEMD}" ] && \
      ( [ -e /sys/module/bnx2i ] || [ -e /sys/module/qedi ] ) && \
       ! [ -e /tmp/iscsiuio-started ]; then
      iscsiuio
      > /tmp/iscsiuio-started
fi


handle_firmware()
{
    local ifaces retry

    # Depending on the 'ql4xdisablesysfsboot' qla4xxx
    # will be autostarting sessions without presenting
    # them via the firmware interface.
    # In these cases 'iscsiadm -m fw' will fail, but
    # the iSCSI sessions will still be present.
    if ! iscsiadm -m fw; then
        warn "iscsiadm: Could not get list of targets from firmware."
    else
        ifaces=$(set -- /sys/firmware/ibft/ethernet*; echo $#)
        retry=$(cat /tmp/session-retry)

        if [ $retry -lt $ifaces ]; then
            retry=$((retry+1))
            echo $retry > /tmp/session-retry
            return 1
        else
            rm /tmp/session-retry
        fi

        if ! iscsiadm -m fw -l; then
            warn "iscsiadm: Log-in to iscsi target failed"
        else
            need_shutdown
        fi
    fi
    [ -d /sys/class/iscsi_session ] || return 1
    echo 'started' > "/tmp/iscsistarted-iscsi:"
    echo 'started' > "/tmp/iscsistarted-firmware"

    return 0
}


handle_netroot()
{
    local iscsi_initiator iscsi_target_name iscsi_target_ip iscsi_target_port
    local iscsi_target_group iscsi_protocol iscsirw iscsi_lun
    local iscsi_username iscsi_password
    local iscsi_in_username iscsi_in_password
    local iscsi_iface_name iscsi_netdev_name
    local iscsi_param param
    local p found
    local login_retry_max_seen=

    # override conf settings by command line options
    arg=$(getarg rd.iscsi.initiator -d iscsi_initiator=)
    [ -n "$arg" ] && iscsi_initiator=$arg
    arg=$(getarg rd.iscsi.target.group -d iscsi_target_group=)
    [ -n "$arg" ] && iscsi_target_group=$arg
    arg=$(getarg rd.iscsi.username -d iscsi_username=)
    [ -n "$arg" ] && iscsi_username=$arg
    arg=$(getarg rd.iscsi.password -d iscsi_password)
    [ -n "$arg" ] && iscsi_password=$arg
    arg=$(getarg rd.iscsi.in.username -d iscsi_in_username=)
    [ -n "$arg" ] && iscsi_in_username=$arg
    arg=$(getarg rd.iscsi.in.password -d iscsi_in_password=)
    [ -n "$arg" ] && iscsi_in_password=$arg
    for p in $(getargs rd.iscsi.param -d iscsi_param); do
        [ "${p%=*}" = node.session.initial_login_retry_max ] && \
            login_retry_max_seen=yes
            iscsi_param="$iscsi_param $p"
    done

    # this sets iscsi_target_name and possibly overwrites most
    # parameters read from the command line above
    parse_iscsi_root "$1" || return 1

    # Bail out early, if there is no route to the destination
    if is_ip "$iscsi_target_ip" && [ "$netif" != "timeout" ] && ! all_ifaces_setup && getargbool 1 rd.iscsi.testroute; then
        ip route get "$iscsi_target_ip" >/dev/null 2>&1 || return 0
    fi

    #limit iscsistart login retries
    if [ "$login_retry_max_seen" != yes ]; then
        retries=$(getargnum 3 0 10000 rd.iscsi.login_retry_max)
        if [ $retries -gt 0 ]; then
            iscsi_param="${iscsi_param% } node.session.initial_login_retry_max=$retries"
        fi
    fi

# XXX is this needed?
    getarg ro && iscsirw=ro
    getarg rw && iscsirw=rw
    fsopts=${fsopts:+$fsopts,}${iscsirw}

    if [ -z "$iscsi_initiator" ] && [ -f /sys/firmware/ibft/initiator/initiator-name ] && ! [ -f /tmp/iscsi_set_initiator ]; then
           iscsi_initiator=$(while read line || [ -n "$line" ]; do echo $line;done < /sys/firmware/ibft/initiator/initiator-name)
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

    if [ -z "$iscsi_initiator" ]; then
        [ -f /run/initiatorname.iscsi ] && . /run/initiatorname.iscsi
        [ -f /etc/initiatorname.iscsi ] && . /etc/initiatorname.iscsi
        [ -f /etc/iscsi/initiatorname.iscsi ] && . /etc/iscsi/initiatorname.iscsi
        iscsi_initiator=$InitiatorName
    fi

    if [ -z "$iscsi_initiator" ]; then
        iscsi_initiator=$(iscsi-iname)
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


    if [ -z "$iscsi_target_port" ]; then
        iscsi_target_port=3260
    fi

    if [ -z "$iscsi_target_group" ]; then
        iscsi_target_group=1
    fi

    if [ -z "$iscsi_lun" ]; then
        iscsi_lun=0
    fi

    echo "InitiatorName=$iscsi_initiator" > /run/initiatorname.iscsi
    ln -fs /run/initiatorname.iscsi /dev/.initiatorname.iscsi
    if ! [ -e /etc/iscsi/initiatorname.iscsi ]; then
        mkdir -p /etc/iscsi
        ln -fs /run/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
        if [ -n "$DRACUT_SYSTEMD" ]; then
            systemctl try-restart iscsid
            # FIXME: iscsid is not yet ready, when the service is :-/
            sleep 1
        fi
    fi

   if [ -z "$DRACUT_SYSTEMD" ]; then
       iscsid
       sleep 2
   fi

# FIXME $iscsi_protocol??

    if [ "$root" = "dhcp" ] || [ "$netroot" = "dhcp" ]; then
        # if root is not specified try to mount the whole iSCSI LUN
        printf 'SYMLINK=="disk/by-path/*-iscsi-*-%s", SYMLINK+="root"\n' "$iscsi_lun" >> /etc/udev/rules.d/99-iscsi-root.rules
        udevadm control --reload
        write_fs_tab /dev/root
        wait_for_dev -n /dev/root

        # install mount script
        [ -z "$DRACUT_SYSTEMD" ] && \
            echo "iscsi_lun=$iscsi_lun . /bin/mount-lun.sh " > $hookdir/mount/01-$$-iscsi.sh
    fi

    targets=$(iscsiadm -m discovery -t st -p $iscsi_target_ip:${iscsi_target_port:+$iscsi_target_port} | sed 's/^.*iqn/iqn/')
    [ -z "$targets" ] && echo "Target discovery to $iscsi_target_ip:${iscsi_target_port:+$iscsi_target_port} failed with status $?" && exit 1

    found=
    for target in $targets; do
        if [ "$target" = "$iscsi_target_name" ]; then
            if [ -n "$iscsi_iface_name" ]; then
                iscsiadm -m iface -I $iscsi_iface_name --op=new
                EXTRA=" ${iscsi_netdev_name:+--name=iface.net_ifacename --value=$iscsi_netdev_name} "
                EXTRA="$EXTRA ${iscsi_initiator:+--name=iface.initiatorname --value=$iscsi_initiator} "
            fi
            [ -n "$iscsi_param" ] && for param in $iscsi_param; do EXTRA="$EXTRA --name=${param%=*} --value=${param#*=}"; done

            CMD="iscsiadm -m node -T $target \
                     ${iscsi_iface_name:+-I $iscsi_iface_name} \
                     -p $iscsi_target_ip${iscsi_target_port:+:$iscsi_target_port}"
            __op="--op=update \
                     --name=node.startup --value=onboot \
                     ${iscsi_username:+   --name=node.session.auth.username    --value=$iscsi_username} \
                     ${iscsi_password:+   --name=node.session.auth.password    --value=$iscsi_password} \
                     ${iscsi_in_username:+--name=node.session.auth.username_in --value=$iscsi_in_username} \
                     ${iscsi_in_password:+--name=node.session.auth.password_in --value=$iscsi_in_password} \
                     $EXTRA \
                     $NULL"
            $CMD $__op
            if [ "$netif" != "timeout" ]; then
                $CMD --login
            fi
            found=yes
            break
        fi
    done

    if [ "$netif" = "timeout" ]; then
        iscsiadm -m node -L onboot || :
    elif [ "$found" != yes ]; then
        warn "iSCSI target \"$iscsi_target_name\" not found on portal $iscsi_target_ip:$iscsi_target_port"
        return 1
    fi
    > $hookdir/initqueue/work

    netroot_enc=$(str_replace "$1" '/' '\2f')
    echo 'started' > "/tmp/iscsistarted-iscsi:${netroot_enc}"
    return 0
}

ret=0

if [ "$netif" != "timeout" ] && getargbool 0 rd.iscsi.waitnet; then
    all_ifaces_setup || exit 0
fi

if [ "$netif" = "timeout" ] && all_ifaces_setup; then
    # s.th. went wrong and the timeout script hits
    # restart
    systemctl restart iscsid
    # damn iscsid is not ready after unit says it's ready
    sleep 2
fi

if getargbool 0 rd.iscsi.firmware -d -y iscsi_firmware ; then
    if [ "$netif" = "timeout" ] || [ "$netif" = "online" ] || [ "$netif" = "dummy" ]; then
        [ -f /tmp/session-retry ] || echo 1 > /tmp/session-retry
        handle_firmware
        ret=$?
    fi
fi

if ! [ "$netif" = "online" ]; then
    # loop over all netroot parameter
    if nroot=$(getarg netroot) && [ "$nroot" != "dhcp" ]; then
        for nroot in $(getargs netroot); do
            [ "${nroot%%:*}" = "iscsi" ] || continue
            nroot="${nroot##iscsi:}"
            if [ -n "$nroot" ]; then
                handle_netroot "$nroot"
                ret=$(($ret + $?))
            fi
        done
    else
        if [ -n "$iroot" ]; then
            handle_netroot "$iroot"
            ret=$?
        fi
    fi
fi

need_shutdown

# now we have a root filesystem somewhere in /dev/sd*
# let the normal block handler handle root=
exit $ret
