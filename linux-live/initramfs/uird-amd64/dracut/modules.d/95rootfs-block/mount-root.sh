#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type det_fs >/dev/null 2>&1 || . /lib/fs-lib.sh

mount_root() {
    local _ret
    local _rflags_ro
    # sanity - determine/fix fstype
    rootfs=$(det_fs "${root#block:}" "$fstype")

    journaldev=$(getarg "root.journaldev=")
    if [ -n "$journaldev" ]; then
        case "$rootfs" in
            xfs)
                rflags="${rflags:+${rflags},}logdev=$journaldev"
                ;;
            reiserfs)
                fsckoptions="-j $journaldev $fsckoptions"
                rflags="${rflags:+${rflags},}jdev=$journaldev"
                ;;
            *);;
        esac
    fi

    _rflags_ro="$rflags,ro"
    _rflags_ro="${_rflags_ro##,}"

    while ! mount -t ${rootfs} -o "$_rflags_ro" "${root#block:}" "$NEWROOT"; do
        warn "Failed to mount -t ${rootfs} -o $_rflags_ro ${root#block:} $NEWROOT"
        fsck_ask_err
    done

    READONLY=
    fsckoptions=
    if [ -f "$NEWROOT"/etc/sysconfig/readonly-root ]; then
        . "$NEWROOT"/etc/sysconfig/readonly-root
    fi

    if getargbool 0 "readonlyroot=" -y readonlyroot; then
        READONLY=yes
    fi

    if getarg noreadonlyroot ; then
        READONLY=no
    fi

    if [ -f "$NEWROOT"/fastboot ] || getargbool 0 fastboot ; then
        fastboot=yes
    fi

    if ! getargbool 0 rd.skipfsck; then
        if [ -f "$NEWROOT"/fsckoptions ]; then
            fsckoptions=$(cat "$NEWROOT"/fsckoptions)
        fi

        if [ -f "$NEWROOT"/forcefsck ] || getargbool 0 forcefsck ; then
            fsckoptions="-f $fsckoptions"
        elif [ -f "$NEWROOT"/.autofsck ]; then
            [ -f "$NEWROOT"/etc/sysconfig/autofsck ] && \
                . "$NEWROOT"/etc/sysconfig/autofsck
            if [ "$AUTOFSCK_DEF_CHECK" = "yes" ]; then
                AUTOFSCK_OPT="$AUTOFSCK_OPT -f"
            fi
            if [ -n "$AUTOFSCK_SINGLEUSER" ]; then
                warn "*** Warning -- the system did not shut down cleanly. "
                warn "*** Dropping you to a shell; the system will continue"
                warn "*** when you leave the shell."
                emergency_shell
            fi
            fsckoptions="$AUTOFSCK_OPT $fsckoptions"
        fi
    fi

    rootopts=
    if getargbool 1 rd.fstab -d -n rd_NO_FSTAB \
        && ! getarg rootflags >/dev/null \
        && [ -f "$NEWROOT/etc/fstab" ] \
        && ! [ -L "$NEWROOT/etc/fstab" ]; then
        # if $NEWROOT/etc/fstab contains special mount options for
        # the root filesystem,
        # remount it with the proper options
        rootopts="defaults"
        while read dev mp fs opts dump fsck || [ -n "$dev" ]; do
            # skip comments
            [ "${dev%%#*}" != "$dev" ] && continue

            if [ "$mp" = "/" ]; then
                # sanity - determine/fix fstype
                rootfs=$(det_fs "${root#block:}" "$fs")
                rootopts=$opts
                rootfsck=$fsck
                break
            fi
        done < "$NEWROOT/etc/fstab"
    fi

    # we want rootflags (rflags) to take precedence so prepend rootopts to
    # them
    rflags="${rootopts},${rflags}"
    rflags="${rflags#,}"
    rflags="${rflags%,}"

    # backslashes are treated as escape character in fstab
    # esc_root=$(echo ${root#block:} | sed 's,\\,\\\\,g')
    # printf '%s %s %s %s 1 1 \n' "$esc_root" "$NEWROOT" "$rootfs" "$rflags" >/etc/fstab

    ran_fsck=0
    if fsck_able "$rootfs" && \
        [ "$rootfsck" != "0" -a -z "$fastboot" -a "$READONLY" != "yes" ] && \
            ! strstr "${rflags}" _netdev && \
            ! getargbool 0 rd.skipfsck; then
        umount "$NEWROOT"
        fsck_single "${root#block:}" "$rootfs" "$rflags" "$fsckoptions"
        _ret=$?
        ran_fsck=1
    fi

    echo "${root#block:} $NEWROOT $rootfs ${rflags:-defaults} 0 $rootfsck" >> /etc/fstab

    if ! ismounted "$NEWROOT"; then
        info "Mounting ${root#block:} with -o ${rflags}"
        mount "$NEWROOT" 2>&1 | vinfo
    elif ! are_lists_eq , "$rflags" "$_rflags_ro" defaults; then
        info "Remounting ${root#block:} with -o ${rflags}"
        mount -o remount "$NEWROOT" 2>&1 | vinfo
    fi

    if ! getargbool 0 rd.skipfsck; then
        [ -f "$NEWROOT"/forcefsck ] && rm -f -- "$NEWROOT"/forcefsck 2>/dev/null
        [ -f "$NEWROOT"/.autofsck ] && rm -f -- "$NEWROOT"/.autofsck 2>/dev/null
    fi
}

if [ -n "$root" -a -z "${root%%block:*}" ]; then
    mount_root
fi
