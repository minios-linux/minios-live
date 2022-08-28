#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1

    if ! dracut_module_included "systemd"; then
        derror "systemd-networkd needs systemd in the initramfs"
        return 1
    fi

    return 255
}

# called by dracut
depends() {
    echo "systemd kernel-network-modules"
}

installkernel() {
    return 0
}

# called by dracut
install() {
    inst_multiple -o \
        $systemdutildir/systemd-networkd \
        $systemdutildir/systemd-networkd-wait-online \
        $systemdsystemunitdir/systemd-networkd-wait-online.service \
        $systemdsystemunitdir/systemd-networkd.service \
        $systemdsystemunitdir/systemd-networkd.socket \
        $systemdutildir/network/99-default.link \
        networkctl ip

        #hostnamectl timedatectl
        # $systemdutildir/systemd-timesyncd \
        # $systemdutildir/systemd-timedated \
        # $systemdutildir/systemd-hostnamed \
        # $systemdutildir/systemd-resolvd \
        # $systemdutildir/systemd-resolve-host \
        # $systemdsystemunitdir/systemd-resolved.service \
        # $systemdsystemunitdir/systemd-hostnamed.service \
        # $systemdsystemunitdir/systemd-timesyncd.service \
        # $systemdsystemunitdir/systemd-timedated.service \
        # $systemdsystemunitdir/time-sync.target \
        # /etc/systemd/resolved.conf \


    # inst_dir /var/lib/systemd/clock

    grep '^systemd-network:' $dracutsysrootdir/etc/passwd 2>/dev/null >> "$initdir/etc/passwd"
    grep '^systemd-network:' $dracutsysrootdir/etc/group >> "$initdir/etc/group"
    # grep '^systemd-timesync:' $dracutsysrootdir/etc/passwd 2>/dev/null >> "$initdir/etc/passwd"
    # grep '^systemd-timesync:' $dracutsysrootdir/etc/group >> "$initdir/etc/group"

    _arch=${DRACUT_ARCH:-$(uname -m)}
    inst_libdir_file {"tls/$_arch/",tls/,"$_arch/",}"libnss_dns.so.*" \
                     {"tls/$_arch/",tls/,"$_arch/",}"libnss_mdns4_minimal.so.*" \
                     {"tls/$_arch/",tls/,"$_arch/",}"libnss_myhostname.so.*" \
                     {"tls/$_arch/",tls/,"$_arch/",}"libnss_resolve.so.*"

    for i in \
        systemd-networkd-wait-online.service \
        systemd-networkd.service \
        systemd-networkd.socket
#       systemd-timesyncd.service
    do
        systemctl -q --root "$initdir" enable "$i"
    done
}

