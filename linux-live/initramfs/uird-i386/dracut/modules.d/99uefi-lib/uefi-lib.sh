#!/bin/bash
#
# Copyright 2013 Red Hat, Inc.  All rights reserved.
# Copyright 2013 Harald Hoyer <harald@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

getbyte () {
    local IFS= LC_CTYPE=C res c=0
    read -r -n 1 -d '' c
    res=$?
    # the single quote in the argument of the printf
    # yields the numeric value of $c (ASCII since LC_CTYPE=C)
    [[ -n $c ]] && c=$(printf '%u' "'$c") || c=0
    printf "$c"
    return $res
}

getword () {
    local b1=0 b2=0 val=0
    b1=$(getbyte)
    b2=$(getbyte)
    (( val = b2 * 256 + b1 ))
    echo $val
    return 0
}

# Acpi(PNP0A08,0x0)/Pci(0x3,0x0)/Pci(0x0,0x0)/MAC(90E2BA265ED4,0x0)/Vlan(172)/Fibre(0x4EA06104A0CC0050,0x0)
uefi_device_path()
{
    data=${1:-/sys/firmware/efi/vars/FcoeBootDevice-a0ebca23-5f9c-447a-a268-22b6c158c2ac/data}
    [ -f "$data" ] || return 1

    local IFS= LC_CTYPE=C res tt len type hextype first
    first=1
    {
        getword >/dev/null
        getword >/dev/null
        while :; do
            type=$(getbyte) || return 1
            subtype=$(getbyte) || return 1
            len=$(getword) || return 1
            hextype=$(printf "%02x%02x" "$type" "$subtype")
            if [[ $first == 1 ]]; then
                first=0
            elif [[ $hextype != "7fff" ]]; then
                printf "/"
            fi
            case $hextype in
                0101)
                    # PCI
                    tt=$(getword)
                    printf "PCI(0x%x,0x%x)" $(($tt / 256)) $(($tt & 255))
                    ;;
                0201)
                    # ACPI
                    printf "Acpi(0x%x,0x%x)" $(($(getword) + $(getword) * 65536)) $(($(getword) + $(getword) * 65536))
                    ;;
                0303)
                    # FIBRE
                    getword &>/dev/null
                    getword &>/dev/null
                    printf "Fibre(0x%x%x%x%x%x%x%x%x,0x%x)" \
                           $(getbyte) $(getbyte) $(getbyte) $(getbyte) \
                           $(getbyte) $(getbyte) $(getbyte) $(getbyte) \
                           $(( $(getword) + $(getword) * 65536 + 4294967296 * ( $(getword) + $(getword) * 65536 ) ))
                    ;;
                030b)
                    # MAC
                    printf "MAC(%02x%02x%02x%02x%02x%02x," $(getbyte) $(getbyte) $(getbyte) $(getbyte) $(getbyte) $(getbyte)
                    for((i=0; i<26; i++)); do tt=$(getbyte) || return 1; done
                    #read -r -d '' -n 26 tt || return 1
                    printf "0x%x)"  $(getbyte)
                    ;;
                0314)
                    # VLAN
                    printf "VLAN(%d)" $(getword)
                    ;;
                7fff)
                    # END
                    printf "\n"
                    return 0
                    ;;
                *)
                    #printf "Unknown(Type:0x%02x SubType:0x%02x len=%d)\n" "$type" "$subtype" "$len" >&2
                    for((i=0; i<len-4; i++)); do tt=$(getbyte); done
                    ;;
            esac
        done
    } < "$data"
}

# /home/harald/Downloads/FcoeBootDevice-80005007-4248-4e4b-8df4-93060220756f

get_fcoe_boot_mac()
{
    data=${1:-/sys/firmware/efi/vars/FcoeBootDevice-a0ebca23-5f9c-447a-a268-22b6c158c2ac/data}
    [ -f "$data" ] || return 1
    local IFS= LC_CTYPE=C tt len type hextype
    {
        getword >/dev/null
        getword >/dev/null
        while :; do
            type=$(getbyte) || return 1
            subtype=$(getbyte) || return 1
            len=$(getword) || return 1
            hextype=$(printf "%02x%02x" "$type" "$subtype")
            case $hextype in
                030b)
                    # MAC
                    printf "%02x:%02x:%02x:%02x:%02x:%02x" $(getbyte) $(getbyte) $(getbyte) $(getbyte) $(getbyte) $(getbyte)
                    for((i=0; i<27; i++)); do tt=$(getbyte) || return 1; done
                    ;;
                7fff)
                    # END
                    return 0
                    ;;
                *)
                    #printf "Unknown(Type:0x%02x SubType:0x%02x len=%d)\n" "$type" "$subtype" "$len" >&2
                    for((i=0; i<len-4; i++)); do tt=$(getbyte); done
                    ;;
            esac
        done
    } < "$data"
}

get_fcoe_boot_vlan()
{
    data=${1:-/sys/firmware/efi/vars/FcoeBootDevice-a0ebca23-5f9c-447a-a268-22b6c158c2ac/data}
    [ -f "$data" ] || return 1
    local IFS= LC_CTYPE=C tt len type hextype
    {
        getword >/dev/null
        getword >/dev/null
        while :; do
            type=$(getbyte) || return 1
            subtype=$(getbyte) || return 1
            len=$(getword) || return 1
            hextype=$(printf "%02x%02x" "$type" "$subtype")
            case $hextype in
                0314)
                    # VLAN
                    printf "%d" $(getword)
                    ;;
                7fff)
                    # END
                    return 0
                    ;;
                *)
                    #printf "Unknown(Type:0x%02x SubType:0x%02x len=%d)\n" "$type" "$subtype" "$len" >&2
                    for((i=0; i<len; i++)); do tt=$(getbyte); done
                    ;;
            esac
        done
    } < "$data"
}
