#!/bin/bash

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    echo udev-rules
    return 0
}

# called by dracut
install() {
    local _d

    inst_multiple mount mknod mkdir sleep chroot chown \
        sed ls flock cp mv dmesg rm ln rmmod mkfifo umount readlink setsid \
        modprobe

    inst_multiple -o findmnt less kmod

    if [ ! -e "${initdir}/bin/sh" ]; then
        inst_multiple bash
        (ln -s bash "${initdir}/bin/sh" || :)
    fi

    # add common users in /etc/passwd, it will be used by nfs/ssh currently
    # use password for hostonly images to facilitate secure sulogin in emergency console
    [[ $hostonly ]] && pwshadow='x'
    grep '^root:' "$initdir/etc/passwd" 2>/dev/null || echo  "root:$pwshadow:0:0::/root:/bin/sh" >> "$initdir/etc/passwd"
    grep '^nobody:' $dracutsysrootdir/etc/passwd >> "$initdir/etc/passwd"

    [[ $hostonly ]] && grep '^root:' $dracutsysrootdir/etc/shadow >> "$initdir/etc/shadow"

    # install our scripts and hooks
    inst_script "$moddir/init.sh" "/init"
    inst_script "$moddir/initqueue.sh" "/sbin/initqueue"
    inst_script "$moddir/loginit.sh" "/sbin/loginit"
    inst_script "$moddir/rdsosreport.sh" "/sbin/rdsosreport"
    inst_script "$moddir/memtrace-ko.sh" "/sbin/tracekomem"

    [ -e "${initdir}/lib" ] || mkdir -m 0755 -p ${initdir}/lib
    mkdir -m 0755 -p ${initdir}/lib/dracut
    mkdir -m 0755 -p ${initdir}/lib/dracut/hooks

    mkdir -p ${initdir}/tmp

    inst_simple "$moddir/dracut-lib.sh" "/lib/dracut-lib.sh"
    mkdir -p "${initdir}/var"

    if ! dracut_module_included "systemd"; then
        inst_multiple switch_root || dfatal "Failed to install switch_root"
        inst_hook cmdline 10 "$moddir/parse-root-opts.sh"
        inst_multiple -o $systemdutildir/systemd-timestamp
    fi

    if [[ $realinitpath ]]; then
        for i in $realinitpath; do
            echo "rd.distroinit=$i"
        done > "${initdir}/etc/cmdline.d/distroinit.conf"
    fi

    ln -fs /proc/self/mounts "$initdir/etc/mtab"
    if [[ $ro_mnt = yes ]]; then
        echo ro >> "${initdir}/etc/cmdline.d/base.conf"
    fi

    [ -e "${initdir}/usr/lib" ] || mkdir -m 0755 -p ${initdir}/usr/lib

    local VERSION=""
    local PRETTY_NAME=""
    # Derive an os-release file from the host, if it exists
    if [ -e $dracutsysrootdir/etc/os-release ]; then
        . $dracutsysrootdir/etc/os-release
        grep -hE -ve '^VERSION=' -ve '^PRETTY_NAME' $dracutsysrootdir/etc/os-release >${initdir}/usr/lib/initrd-release
        [[ -n ${VERSION} ]] && VERSION+=" "
        [[ -n ${PRETTY_NAME} ]] && PRETTY_NAME+=" "
    else
        # Fall back to synthesizing one, since dracut is presently used
        # on non-systemd systems as well.
        {
            echo NAME=dracut
            echo ID=dracut
            echo VERSION_ID=\"$DRACUT_VERSION\"
            echo ANSI_COLOR='"0;34"'
        } >${initdir}/usr/lib/initrd-release
    fi
    VERSION+="dracut-$DRACUT_VERSION"
    PRETTY_NAME+="dracut-$DRACUT_VERSION (Initramfs)"
    {
        echo VERSION=\"$VERSION\"
        echo PRETTY_NAME=\"$PRETTY_NAME\"
        # This addition is relatively new, intended to allow software
        # to easily detect the dracut version if need be without
        # having it mixed in with the real underlying OS version.
        echo DRACUT_VERSION=\"${DRACUT_VERSION}\"
    } >> $initdir/usr/lib/initrd-release
    echo dracut-$DRACUT_VERSION > $initdir/lib/dracut/dracut-$DRACUT_VERSION
    ln -sf ../usr/lib/initrd-release $initdir/etc/initrd-release
    ln -sf initrd-release $initdir/usr/lib/os-release
    ln -sf initrd-release $initdir/etc/os-release

    ## save host_devs which we need bring up
    if [[ $hostonly_cmdline == "yes" ]]; then
        if [[ -n "${host_devs[@]}" ]]; then
            dracut_need_initqueue
        fi
        if [[ -f "$initdir/lib/dracut/need-initqueue" ]] || ! dracut_module_included "systemd"; then
            (
                if dracut_module_included "systemd"; then
                    DRACUT_SYSTEMD=1
                fi
                PREFIX="$initdir"

                . "$moddir/dracut-lib.sh"

                for _dev in "${host_devs[@]}"; do
                    for _dev2 in "${root_devs[@]}"; do
                        [[ "$_dev" == "$_dev2" ]] && continue 2
                    done

                    # We only actually wait for real devs - swap is only needed
                    # for resume and udev rules generated when parsing resume=
                    # argument take care of the waiting for us
                    for _dev2 in "${swap_devs[@]}"; do
                      [[ "$_dev" == "$_dev2" ]] && continue 2
                    done

                    _pdev=$(get_persistent_dev $_dev)

                    case "$_pdev" in
                        /dev/?*) wait_for_dev $_pdev;;
                        *) ;;
                    esac
                done
            )
        fi
    fi
}
