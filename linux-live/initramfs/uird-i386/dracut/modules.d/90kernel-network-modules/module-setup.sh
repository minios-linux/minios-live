#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    # Include wired net drivers, excluding wireless
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local _net_drivers='eth_type_trans|register_virtio_device|usbnet_open'
    local _unwanted_drivers='/(wireless|isdn|uwb|net/ethernet|net/phy|net/team)/'

    if [ "$_arch" = "s390" -o "$_arch" = "s390x" ]; then
        _s390drivers="=drivers/s390/net"
    fi

    dracut_instmods -o -P ".*${_unwanted_drivers}.*" -s "$_net_drivers" "=drivers/net" ${_s390drivers:+"$_s390drivers"}

    #instmods() will take care of hostonly
    instmods \
        =drivers/net/phy \
        =drivers/net/team \
        =drivers/net/ethernet \
        ecb arc4 bridge stp llc ipv6 bonding 8021q ipvlan macvlan af_packet virtio_net xennet
    hostonly="" instmods iscsi_ibft crc32c iscsi_boot_sysfs
}

# called by dracut
install() {
    return 0
}

