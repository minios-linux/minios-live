#!/bin/bash

# called by dracut
check() {
    local _program

    require_binaries sed grep || return 1

    # do not add this module by default
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    return 0
}

# called by dracut
install() {
    local _nm_version

    _nm_version=$(NetworkManager --version)

    # We don't need `ip` but having it is *really* useful for people debugging
    # in an emergency shell.
    inst_multiple ip sed grep

    inst NetworkManager
    inst /usr/libexec/nm-initrd-generator
    inst_multiple -o teamd dhclient
    inst_hook cmdline 99 "$moddir/nm-config.sh"
    inst_hook initqueue/settled 99 "$moddir/nm-run.sh"
    inst_rules 85-nm-unmanaged.rules
    inst_libdir_file "NetworkManager/$_nm_version/libnm-device-plugin-team.so"

    if [[ -x "$initdir/usr/sbin/dhclient" ]]; then
        inst /usr/libexec/nm-dhcp-helper
    elif ! [[ -e "$initdir/etc/machine-id" ]]; then
        # The internal DHCP client silently fails if we
        # have no machine-id
        systemd-machine-id-setup --root="$initdir"
    fi

    # We don't install the ifcfg files from the host automatically.
    # But if the user chooses to include them, we pull in the machinery to read them.
    if ! [[ -d "$initdir/etc/sysconfig/network-scripts" ]]; then
        inst_libdir_file "NetworkManager/$_nm_version/libnm-settings-plugin-ifcfg-rh.so"
    fi
}
