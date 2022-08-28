#!/bin/bash

command -v getarg >/dev/null          || . /lib/dracut-lib.sh
command -v get_fcoe_boot_mac >/dev/null || . /lib/uefi-lib.sh
command -v set_ifname >/dev/null || . /lib/net-lib.sh

print_fcoe_uefi_conf()
{
    local mac dev vlan
    mac=$(get_fcoe_boot_mac "$1")
    [ -z "$mac" ] && return 1
    dev=$(set_ifname fcoe $mac)
    vlan=$(get_fcoe_boot_vlan  "$1")
    if [ "$vlan" -ne "0" ]; then
        case "$vlan" in
            [0-9]*)
                printf "%s\n" "vlan=$dev.$vlan:$dev"
                dev="$dev.$vlan"
                ;;
            *)
                printf "%s\n" "vlan=$vlan:$dev"
                dev="$vlan"
                ;;
        esac
    fi
    # fcoe=eth0:nodcb
    printf "fcoe=%s\n" "$dev:nodcb"
    return 0
}

for i in /sys/firmware/efi/vars/FcoeBootDevice-*/data; do
    [ -e "$i" ] || continue
    print_fcoe_uefi_conf $i > /etc/cmdline.d/40-fcoe-uefi.conf && break
done
