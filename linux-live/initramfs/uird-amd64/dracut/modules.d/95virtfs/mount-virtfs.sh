#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

filter_rootopts() {
    rootopts=$1
    # strip ro and rw options
    local OLDIFS="$IFS"
    IFS=,
    set -- $rootopts
    IFS="$OLDIFS"
    local v
    while [ $# -gt 0 ]; do
        case $1 in
            rw|ro);;
            defaults);;
            *)
                v="$v,${1}";;
        esac
        shift
    done
    rootopts=${v#,}
    echo $rootopts
}

mount_root() {
    local _ret

    rootfs="9p"
    rflags="trans=virtio,version=9p2000.L"

    modprobe 9pnet_virtio

    mount -t ${rootfs} -o "$rflags",ro "${root#virtfs:}" "$NEWROOT"

    rootopts=
    if getargbool 1 rd.fstab -n rd_NO_FSTAB \
        && ! getarg rootflags \
        && [ -f "$NEWROOT/etc/fstab" ] \
        && ! [ -L "$NEWROOT/etc/fstab" ]; then
        # if $NEWROOT/etc/fstab contains special mount options for
        # the root filesystem,
        # remount it with the proper options
        rootopts="defaults"
        while read dev mp fs opts rest || [ -n "$dev" ]; do
            # skip comments
            [ "${dev%%#*}" != "$dev" ] && continue

            if [ "$mp" = "/" ]; then
                rootopts=$opts
                break
            fi
        done < "$NEWROOT/etc/fstab"

        rootopts=$(filter_rootopts $rootopts)
    fi

    # we want rootflags (rflags) to take precedence so prepend rootopts to
    # them; rflags is guaranteed to not be empty
    rflags="${rootopts:+${rootopts},}${rflags}"

    umount "$NEWROOT"

    info "Remounting ${root#virtfs:} with -o ${rflags}"
    mount -t ${rootfs} -o "$rflags" "${root#virtfs:}" "$NEWROOT" 2>&1 | vinfo

    [ -f "$NEWROOT"/forcefsck ] && rm -f -- "$NEWROOT"/forcefsck 2>/dev/null
    [ -f "$NEWROOT"/.autofsck ] && rm -f -- "$NEWROOT"/.autofsck 2>/dev/null
}

if [ -n "$root" -a -z "${root%%virtfs:*}" ]; then
    mount_root
fi
:
