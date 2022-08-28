#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    return 0
}

depends() {
    # We depend on magos modules being loaded
#    echo magos
    return 0
}


install() {
    #dracut_install /usr/bin/vim

    inst /usr/bin/git
#    inst_multiple \
#		/usr/lib64/git-core/git-sh-i18n \
#		/usr/lib64/git-core/git-sh-i18n--envsubst \
#		/usr/lib64/git-core/git-sh-setup \
#		/usr/lib64/git-core/git-http-backend \
#		/usr/lib64/git-core/git-http-fetch \
#		/usr/lib64/git-core/git-http-push \
#		/usr/lib64/git-core/git-stash \
#		/usr/lib64/git-core/git-remote-https \
#		/usr/lib64/git-core/git-svn \
#		/usr/lib64/git-core/git-submodule \
#		/usr/lib64/git-core/git-parse-remote \ 
#		/usr/lib64/git-core/git-rebase \
#		/usr/lib64/git-core/git-rebase--am \
#		/usr/lib64/git-core/git-rebase--interactive \
#		/usr/lib64/git-core/git-rebase--merge
    inst_multiple /usr/lib64/git-core/*
    
    inst_multiple /usr/lib64/gcc/x86_64-unknown-linux-gnu/5.5.0/*
    inst_multiple /usr/lib64/gcc/x86_64-unknown-linux-gnu/5.5.0/32/*
    inst_multiple /usr/lib64/gcc/x86_64-unknown-linux-gnu/5.5.0/include/*
    inst_multiple /usr/lib64/gcc/x86_64-unknown-linux-gnu/5.5.0/install-tools/*
    inst_multiple /usr/include/*
    inst_multiple /usr/include/sys/*
    inst_multiple /usr/include/bits/*
    inst_multiple /usr/include/gnu/*
    inst_multiple /usr/include/linux/*
    inst_multiple /usr/include/linux/raid/*
    inst_multiple /usr/include/linux/hdlc/*
    inst_multiple /usr/include/asm/*
    inst_multiple /usr/include/asm-generic/*
    inst_multiple /usr/include/kmod-25/*
    inst_multiple /usr/include/arpa/*
    inst_multiple /usr/include/netinet/*

    inst_multiple /usr/include/rpc/*
    inst_multiple /usr/include/net/*
    inst_multiple /usr/include/mtd/*
    inst_multiple /usr/include/netpacket/*
    inst_multiple /usr/include/scsi/*
#    inst_multiple /usr/include/.../*

    inst /usr/lib64/crt1.o
    inst /usr/lib64/crti.o
    inst /usr/lib64/crtn.o
    
    inst /usr/lib64/libc.so
    inst /usr/lib64/libkmod.so
    inst /usr/lib64/libc_nonshared.a
    inst /usr/lib64/libm.so
    inst /lib64/libmvec.so.1
    inst /usr/lib64/libmvec_nonshared.a
    
    inst pkg-config
    inst /usr/lib64/pkgconfig/libkmod.pc

    inst cc
    inst as
    inst ar
    inst objcopy
    inst objdump
    inst gcc
    inst g++
    inst ld
    inst make
    inst sort
    inst cp
    inst xz /bin/xz
    inst ldconfig
    inst ldd
    inst strip
    inst mksquashfs
    inst unsquashfs
    inst realpath /bin/realpath
    inst ln
    inst egrep
    inst hardlink /bin/hardlink
}

