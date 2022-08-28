#!/bin/bash

create_udev_rule() {
    local ccw=$1
    local _drv _cu_type _dev_type
    local _rule=/etc/udev/rules.d/51-dasd-${ccw}.rules

    if [ -x /sbin/cio_ignore ] && cio_ignore -i $ccw > /dev/null ; then
        cio_ignore -r $ccw
    fi

    if [ -e /sys/bus/ccw/devices/${ccw} ] ; then
        read _cu_type < /sys/bus/ccw/devices/${ccw}/cutype
        read _dev_type < /sys/bus/ccw/devices/${ccw}/devtype
    fi
    case "$_cu_type" in
    3990/*|2105/*|2107/*|1750/*|9343/*)
            _drv=dasd-eckd
            ;;
    6310/*)
            _drv=dasd-fba
            ;;
    3880/*)
        case "$_dev_type" in
            3380/*)
                _drv=dasd_eckd
                ;;
            3370/*)
                _drv=dasd-fba
                ;;
        esac
        ;;
    esac
    [ -z "${_drv}" ] && return 0

    [ -e ${_rule} ] && return 0

    cat > $_rule <<EOF
ACTION=="add", SUBSYSTEM=="ccw", KERNEL=="$ccw", IMPORT{program}="collect $ccw %k ${ccw} $_drv"
ACTION=="add", SUBSYSTEM=="drivers", KERNEL=="$_drv", IMPORT{program}="collect $ccw %k ${ccw} $_drv"
ACTION=="add", ENV{COLLECT_$ccw}=="0", ATTR{[ccw/$ccw]online}="1"
EOF
}

if [[ -f /sys/firmware/ipl/ipl_type &&
            $(</sys/firmware/ipl/ipl_type) = "ccw" ]] ; then
    (
        local _ccw=$(cat /sys/firmware/ipl/device)

        create_udev_rule $_ccw
    )
fi

for dasd_arg in $(getargs root=) $(getargs resume=); do
    (
        case $dasd_arg in
            /dev/disk/by-path/ccw-*)
                ccw_arg=${dasd_arg##*/}
                ;;
        esac
        if [ -n "$ccw_arg" ] ; then
            OLDIFS="$IFS"
            IFS="-"
            set -- $ccw_arg
            IFS="$OLDIFS"
            create_udev_rule $2
        fi
    )
done

for dasd_arg in $(getargs rd.dasd=); do
    (
        OLDIFS="$IFS"
        IFS=","
        set -- $dasd_arg
        IFS="$OLDIFS"
        while (($# > 0)); do
            case $1 in
                autodetect|probeonly)
                    shift
                    ;;
                *-*)
                    range=$1
                    OLDIFS="$IFS"
                    IFS="-"
                    set -- $range
                    prefix=${1%.*}
                    start=${1##*.}
                    shift
                    end=${1##.}
                    shift
                    IFS="$OLDIFS"
                    for dev in $(seq $(( 16#$start )) $(( 16#$end )) ) ; do
                        create_udev_rule $(printf "%s.%04x" "$prefix" "$dev")
                    done
                    ;;
                *)
                    dev=${1%(ro)}
                    if [ "$dev" != "$1" ] ; then
                        ro=1
                    fi
                    OLDIFS="$IFS"
                    IFS="."
                    set -- $dev
                    sid=$1
                    shift
                    ssid=$1
                    shift
                    chan=$1
                    IFS="$OLDIFS"
                    create_udev_rule $(printf "%01x.%01x.%04x" $(( 16#$sid )) $(( 16#$ssid )) $(( 16#$chan )) )
                    shift
                    ;;
            esac
        done
    )
done
