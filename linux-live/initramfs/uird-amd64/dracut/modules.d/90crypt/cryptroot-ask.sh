#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
NEWROOT=${NEWROOT:-"/sysroot"}

# do not ask, if we already have root
[ -f $NEWROOT/proc ] && exit 0

. /lib/dracut-lib.sh

mkdir -m 0700 /run/cryptsetup

# if device name is /dev/dm-X, convert to /dev/mapper/name
if [ "${1##/dev/dm-}" != "$1" ]; then
    device="/dev/mapper/$(dmsetup info -c --noheadings -o name "$1")"
else
    device="$1"
fi

# default luksname - luks-UUID
luksname=$2

# number of tries
numtries=${3:-10}

# TODO: improve to support what cmdline does
if [ -f /etc/crypttab ] && getargbool 1 rd.luks.crypttab -d -n rd_NO_CRYPTTAB; then
    while read name dev luksfile luksoptions || [ -n "$name" ]; do
        # ignore blank lines and comments
        if [ -z "$name" -o "${name#\#}" != "$name" ]; then
            continue
        fi

        # PARTUUID used in crypttab
        if [ "${dev%%=*}" = "PARTUUID" ]; then
            if [ "luks-${dev##PARTUUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi

        # UUID used in crypttab
        elif [ "${dev%%=*}" = "UUID" ]; then
            if [ "luks-${dev##UUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi

        # ID used in crypttab
        elif [ "${dev%%=*}" = "ID" ]; then
            if [ "luks-${dev##ID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi

        # path used in crypttab
        else
            cdev=$(readlink -f $dev)
            mdev=$(readlink -f $device)
            if [ "$cdev" = "$mdev" ]; then
                luksname="$name"
                break
            fi
        fi
    done < /etc/crypttab
    unset name dev
fi

# check if destination already exists
[ -b /dev/mapper/$luksname ] && exit 0

# we already asked for this device
asked_file=/tmp/cryptroot-asked-$luksname
[ -f $asked_file ] && exit 0

# load dm_crypt if it is not already loaded
[ -d /sys/module/dm_crypt ] || modprobe dm_crypt

. /lib/dracut-crypt-lib.sh

#
# Open LUKS device
#

info "luksOpen $device $luksname $luksfile $luksoptions"

OLD_IFS="$IFS"
IFS=,
set -- $luksoptions
IFS="$OLD_IFS"

while [ $# -gt 0 ]; do
    case $1 in
        noauto)
            # skip this
            exit 0
            ;;
        swap)
            # skip this
            exit 0
            ;;
        tmp)
            # skip this
            exit 0
            ;;
        allow-discards)
            allowdiscards="--allow-discards"
            ;;
        header=*)
            cryptsetupopts="${cryptsetupopts} --${1}"
            ;;
    esac
    shift
done

# parse for allow-discards
if strstr "$(cryptsetup --help)" "allow-discards"; then
    if discarduuids=$(getargs "rd.luks.allow-discards"); then
        discarduuids=$(str_replace "$discarduuids" 'luks-' '')
        if strstr " $discarduuids " " ${luksdev##luks-}"; then
            allowdiscards="--allow-discards"
        fi
    elif getargbool 0 rd.luks.allow-discards; then
        allowdiscards="--allow-discards"
    fi
fi

if strstr "$(cryptsetup --help)" "allow-discards"; then
    cryptsetupopts="$cryptsetupopts $allowdiscards"
fi

unset allowdiscards

# fallback to passphrase
ask_passphrase=1

if [ -n "$luksfile" -a "$luksfile" != "none" -a -e "$luksfile" ]; then
    if cryptsetup --key-file "$luksfile" $cryptsetupopts luksOpen "$device" "$luksname"; then
        ask_passphrase=0
    fi
else
    while [ -n "$(getarg rd.luks.key)" ]; do
        if tmp=$(getkey /tmp/luks.keys $device); then
            keydev="${tmp%%:*}"
            keypath="${tmp#*:}"
        else
            if [ $numtries -eq 0 ]; then
                warn "No key found for $device.  Fallback to passphrase mode."
                break
            fi
            sleep 1
            info "No key found for $device.  Will try $numtries time(s) more later."
            initqueue --unique --onetime --settled \
                --name cryptroot-ask-$luksname \
                $(command -v cryptroot-ask) "$device" "$luksname" "$(($numtries-1))"
            exit 0
        fi
        unset tmp

        info "Using '$keypath' on '$keydev'"
        readkey "$keypath" "$keydev" "$device" \
            | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname" \
            && ask_passphrase=0
        unset keypath keydev
        break
    done
fi

if [ $ask_passphrase -ne 0 ]; then
    luks_open="$(command -v cryptsetup) $cryptsetupopts luksOpen"
    _timeout=$(getargs "rd.luks.timeout")
    _timeout=${_timeout:-0}
    ask_for_password --ply-tries 5 \
        --ply-cmd "$luks_open -T1 $device $luksname" \
        --ply-prompt "Password ($device)" \
        --tty-tries 1 \
        --tty-cmd "$luks_open -T5 -t $_timeout $device $luksname"
    unset luks_open
    unset _timeout
fi

unset device luksname luksfile

# mark device as asked
>> $asked_file

need_shutdown
udevsettle

exit 0
