#!/bin/sh
#
# Supported formats:
# fcoe=<networkdevice>:<dcb|nodcb>:<fabric|vn2vn>
# fcoe=<macaddress>:<dcb|nodcb>:<fabric|vn2vn>
#
# Note currently only nodcb is supported, the dcb option is reserved for
# future use.
#
# Note letters in the macaddress must be lowercase!
#
# Examples:
# fcoe=eth0:nodcb:vn2vn
# fcoe=4a:3f:4c:04:f8:d7:nodcb:fabric

if getargbool 0 rd.nofcoe ; then
	info "rd.nofcoe=0: skipping fcoe"
	return 0
fi

[ -z "$fcoe" ] && fcoe=$(getarg fcoe=)

# If it's not set we don't continue
[ -z "$fcoe" ] && return

[ -e /sys/bus/fcoe/ctlr_create ] || modprobe -b -a fcoe || modprobe -b -a libfcoe || die "FCoE requested but kernel/initrd does not support FCoE"

initqueue --onetime modprobe -b -q bnx2fc

parse_fcoe_opts() {
    local OLDIFS="$IFS"
    local IFS=:
    set $fcoe
    IFS="$OLDIFS"

    case $# in
        2)
            fcoe_interface=$1
            fcoe_dcb=$2
            fcoe_mode="fabric"
            return 0
            ;;
        3)
            fcoe_interface=$1
            fcoe_dcb=$2
            fcoe_mode=$3
            return 0
            ;;
        7)
            fcoe_mac=$1:$2:$3:$4:$5:$6
            fcoe_dcb=$7
            fcoe_mode="fabric"
            return 0
            ;;
        8)
            fcoe_mac=$1:$2:$3:$4:$5:$6
            fcoe_dcb=$7
            fcoe_mode=$8
            return 0
            ;;
        *)
            warn "Invalid arguments for fcoe=$fcoe"
            return 1
            ;;
    esac
}

parse_fcoe_opts

if [ "$fcoe_interface" = "edd" ]; then
    if [ "$fcoe_dcb" != "nodcb" -a "$fcoe_dcb" != "dcb" ] ; then
        warn "Invalid FCoE DCB option: $fcoe_dcb"
    fi
    /sbin/initqueue --settled --unique /sbin/fcoe-edd $fcoe_dcb
else
    for fcoe in $(getargs fcoe=); do
        unset fcoe_mac
        unset fcoe_interface
        parse_fcoe_opts
        if [ "$fcoe_dcb" != "nodcb" -a "$fcoe_dcb" != "dcb" ] ; then
            warn "Invalid FCoE DCB option: $fcoe_dcb"
        fi
        . $(command -v fcoe-genrules.sh)
    done
fi
