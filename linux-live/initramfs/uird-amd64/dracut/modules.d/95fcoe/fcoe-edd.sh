#!/bin/sh

dcb="$1"

_modprobe_r_edd="0"

check_edd() {
    local cnt=0

    [ -d /sys/firmware/edd ] && return 0

    _modprobe_r_edd="1"
    modprobe edd || return $?

    while [ $cnt -lt 600 ]; do
        [ -d /sys/firmware/edd ] && return 0
        cnt=$(($cnt+1))
        sleep 0.1
    done
    return 1
}

check_edd || exit 1

for disk in /sys/firmware/edd/int13_*; do
    [ -d "$disk" ] || continue
    if [ -e "${disk}/pci_dev/driver" ]; then
	    driver=$(readlink "${disk}/pci_dev/driver")
	    driver=${driver##*/}
    fi
    # i40e uses dev_port 1 for a virtual fcoe function
    if [ "${driver}" = "i40e" ]; then
	    dev_port=1
    fi
    for nic in "${disk}"/pci_dev/net/*; do
        [ -d "$nic" ] || continue
	if [ -n "${dev_port}" -a -e "${nic}/dev_port" ]; then
		if [ "$(cat ${nic}/dev_port)" -ne "${dev_port}" ]; then
			continue
		fi
	fi
        if [ -e ${nic}/address ]; then
	    fcoe_interface=${nic##*/}
	    if ! [ -e "/tmp/.fcoe-$fcoe_interface" ]; then
		/sbin/fcoe-up "$fcoe_interface" "$dcb"
		> "/tmp/.fcoe-$fcoe_interface"
	    fi
        fi
    done
done

[ "$_modprobe_r_edd" = "1" ] && modprobe -r edd

unset _modprobe_r_edd
