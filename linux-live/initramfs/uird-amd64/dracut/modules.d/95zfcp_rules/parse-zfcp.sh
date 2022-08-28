#!/bin/bash

create_udev_rule() {
    local ccw=$1
    local wwpn=$2
    local lun=$3
    local _rule=/etc/udev/rules.d/51-zfcp-${ccw}.rules
    local _cu_type _dev_type

    if [ -x /sbin/cio_ignore ] && cio_ignore -i $ccw > /dev/null ; then
        cio_ignore -r $ccw
    fi

    if [ -e /sys/bus/ccw/devices/${ccw} ] ; then
        read _cu_type < /sys/bus/ccw/devices/${ccw}/cutype
        read _dev_type < /sys/bus/ccw/devices/${ccw}/devtype
    fi
    if [ "$_cu_type" != "1731/03" ] ; then
        return 0;
    fi
    if [ "$_dev_type" != "1732/03" ] && [ "$_dev_type" != "1732/04" ] ; then
        return 0;
    fi

    if [ ! -f "$_rule" ] ; then
        cat > $_rule <<EOF
ACTION=="add", SUBSYSTEM=="ccw", KERNEL=="$ccw", IMPORT{program}="collect $ccw %k ${ccw} zfcp"
ACTION=="add", SUBSYSTEM=="drivers", KERNEL=="zfcp", IMPORT{program}="collect $ccw %k ${ccw} zfcp"
ACTION=="add", ENV{COLLECT_$ccw}=="0", ATTR{[ccw/$ccw]online}="1"
EOF
    fi
    [ -z "$wwpn" -o -z "$lun" ] && return
    m=$(sed -n "/.*${wwpn}.*${lun}.*/p" $_rule)
    if [ -z "$m" ] ; then
        cat >> $_rule <<EOF
ACTION=="add", KERNEL=="rport-*", ATTR{port_name}=="$wwpn", SUBSYSTEMS=="ccw", KERNELS=="$ccw", ATTR{[ccw/$ccw]$wwpn/unit_add}="$lun"
EOF
    fi
    if [ -x /sbin/cio_ignore ] && ! cio_ignore -i $ccw > /dev/null ; then
        cio_ignore -r $ccw
    fi
}

if [[ -f /sys/firmware/ipl/ipl_type &&
            $(</sys/firmware/ipl/ipl_type) = "fcp" ]] ; then
    (
        local _wwpn=$(cat /sys/firmware/ipl/wwpn)
        local _lun=$(cat /sys/firmware/ipl/lun)
        local _ccw=$(cat /sys/firmware/ipl/device)

        create_udev_rule $_ccw $_wwpn $_lun
    )
fi

for zfcp_arg in $(getargs rd.zfcp); do
    (
        OLDIFS="$IFS"
        IFS=","
        set $zfcp_arg
        IFS="$OLDIFS"
        create_udev_rule $1 $2 $3
    )
done

for zfcp_arg in $(getargs root=) $(getargs resume=); do
    (
        local _wwpn
        local _lun

        case $zfcp_arg in
            /dev/disk/by-path/ccw-*)
                ccw_arg=${zfcp_arg##*/}
                ;;
        esac
        if [ -n "$ccw_arg" ] ; then
            OLDIFS="$IFS"
            IFS="-"
            set -- $ccw_arg
            IFS="$OLDIFS"
            _wwpn=${4%:*}
            _lun=${4#*:}
            create_udev_rule $2 $wwpn $lun
        fi
    )
done
