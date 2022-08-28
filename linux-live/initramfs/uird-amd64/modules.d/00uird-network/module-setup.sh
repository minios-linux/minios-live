#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    return 0
}

depends() {
    # We depend on modules being loaded
    return 0
}

installkernel() {
    return 0
}

install() {
     
    #inst $(type -p sshfs) /sbin/sshfs
    #inst $(type -p curlftpfs) /sbin/curlftpfs
    inst /usr/lib/magos/scripts/httpfs /sbin/httpfs

    _arch=$(uname -m)

    inst_libdir_file {"tls/$_arch/",tls/,"$_arch/",}"libnss_dns.so.*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libnss_mdns4_minimal.so.*"
}

