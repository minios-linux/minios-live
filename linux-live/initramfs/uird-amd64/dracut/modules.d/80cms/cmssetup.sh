#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

function sysecho () {
    file="$1"
    shift
    local i=1
    while [ $i -le 10 ] ; do
        if [ ! -f "$file" ]; then
            sleep 1
            i=$((i+1))
        else
            break
        fi
    done
    local status
    read status < "$file"
    if [[ ! $status == $* ]]; then
        [ -f "$file" ] && echo $* > "$file"
    fi
}

function dasd_settle() {
    local dasd_status=/sys/bus/ccw/devices/$1/status
    if [ ! -f $dasd_status ]; then
        return 1
    fi
    local i=1
    while [ $i -le 60 ] ; do
        local status
        read status < $dasd_status
        case $status in
            online|unformatted)
                return 0 ;;
            *)
                sleep 0.1
                i=$((i+1)) ;;
        esac
    done
    return 1
}

function dasd_settle_all() {
    for dasdccw in $(while read line || [ -n "$line" ]; do echo "${line%%(*}"; done < /proc/dasd/devices) ; do
        if ! dasd_settle $dasdccw ; then
            echo $"Could not access DASD $dasdccw in time"
            return 1
        fi
    done
    return 0
}

# prints a canonocalized device bus ID for a given devno of any format
function canonicalize_devno()
{
    case ${#1} in
        3) echo "0.0.0${1}" ;;
        4) echo "0.0.${1}" ;;
        *) echo "${1}" ;;
    esac
    return 0
}

# read file from CMS and write it to /tmp
function readcmsfile() # $1=dasdport $2=filename
{
    local dev
    local numcpus
    local devname
    local ret=0
    if [ $# -ne 2 ]; then return; fi
    # precondition: udevd created dasda block device node
    if ! dasd_cio_free -d $1 ; then
        echo $"DASD $1 could not be cleared from device blacklist"
        return 1
    fi

    modprobe dasd_mod dasd=$CMSDASD
    modprobe dasd_eckd_mod
    udevadm settle

    # precondition: dasd_eckd_mod driver incl. dependencies loaded,
    #               dasd_mod must be loaded without setting any DASD online
    dev=$(canonicalize_devno $1)
    numcpus=$(
        while read line || [ -n "$line" ]; do
            if strstr "$line" "# processors"; then
                echo ${line##*:};
                break;
            fi;
        done < /proc/cpuinfo
    )

    if [ ${numcpus} -eq 1 ]; then
        echo 1 > /sys/bus/ccw/devices/$dev/online
    else
        if ! sysecho /sys/bus/ccw/devices/$dev/online 1; then
            echo $"DASD $dev could not be set online"
            return 1
        fi
        udevadm settle
        if ! dasd_settle $dev ; then
            echo $"Could not access DASD $dev in time"
            return 1
        fi
    fi

    udevadm settle

    devname=$(cd /sys/bus/ccw/devices/$dev/block; set -- *; [ -b /dev/$1 ] && echo $1)
    devname=${devname:-dasda}

    [[ -d /mnt ]] || mkdir /mnt
    if cmsfs-fuse --to=UTF-8 -a /dev/$devname /mnt; then
        cat /mnt/$2 > /run/initramfs/$2
        umount /mnt || umount -l /mnt
        udevadm settle
    else
        echo $"Could not read conf file $2 on CMS DASD $1."
        ret=1
    fi

    if ! sysecho /sys/bus/ccw/devices/$dev/online 0; then
        echo $"DASD $dev could not be set offline again"
        #return 1
    fi
    udevadm settle

    # unbind all dasds to unload the dasd modules for a clean start
    ( cd /sys/bus/ccw/drivers/dasd-eckd; for i in *.*; do echo $i > unbind;done)
    udevadm settle
    modprobe -r dasd_eckd_mod
    udevadm settle
    modprobe -r dasd_diag_mod
    udevadm settle
    modprobe -r dasd_mod
    udevadm settle
    return $ret
}

processcmsfile()
{
    source /tmp/cms.conf
    SUBCHANNELS="$(echo $SUBCHANNELS | sed 'y/ABCDEF/abcdef/')"

    if [[ $NETTYPE ]]; then
        (
            echo -n $NETTYPE,$SUBCHANNELS
            [[ $PORTNAME ]] && echo -n ",portname=$PORTNAME"
            [[ $LAYER2 ]] && echo -n ",layer2=$LAYER2"
            [[ "$NETTYPE" = "ctc" ]] && [[ $CTCPROT ]] && echo -n ",protocol=$CTCPROT"
            echo
        ) >> /etc/ccw.conf

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

        printf 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="%s", KERNELS=="%s", ENV{INTERFACE}=="?*", RUN+="/sbin/initqueue --onetime --unique --name cmsifup-$name /sbin/cmsifup $name"\n' "$driver" "$devbusid" > /etc/udev/rules.d/99-cms.rules
        # remove the default net rules
        rm -f -- /etc/udev/rules.d/91-default-net.rules
        [[ -f /etc/udev/rules.d/90-net.rules ]] \
            || printf 'SUBSYSTEM=="net", ACTION=="online", RUN+="/sbin/initqueue --onetime --env netif=$name source_hook initqueue/online"\n' >> /etc/udev/rules.d/99-cms.rules
        udevadm control --reload
        znet_cio_free
    fi

    if [[ $DASD ]] && [[ $DASD != "none" ]]; then
        echo $DASD | normalize_dasd_arg > /etc/dasd.conf
        echo "options dasd_mod dasd=$DASD" > /etc/modprobe.d/dasd_mod.conf
        dasd_cio_free
    fi

    unset _do_zfcp
    for i in ${!FCP_*}; do
        echo "${!i}" | while read port rest || [ -n "$port" ]; do
            case $port in
                *.*.*)
                    ;;
                *.*)
                    port="0.$port"
                    ;;
                *)
                    port="0.0.$port"
                    ;;
            esac
            echo $port $rest >> /etc/zfcp.conf
        done
        _do_zfcp=1
    done
    [[ $_do_zfcp ]] && zfcp_cio_free
    unset _do_zfcp
}

[[ $CMSDASD ]] || CMSDASD=$(getarg "CMSDASD=")
[[ $CMSCONFFILE ]] || CMSCONFFILE=$(getarg "CMSCONFFILE=")

# Parse configuration
if [ -n "$CMSDASD" -a -n "$CMSCONFFILE" ]; then
    if readcmsfile $CMSDASD $CMSCONFFILE; then
        ln -s /run/initramfs/$CMSCONFFILE /tmp/$CMSCONFFILE
        ln -s /run/initramfs/$CMSCONFFILE /tmp/cms.conf
        processcmsfile
    fi
fi
