#!/bin/sh

type info >/dev/null 2>&1 || . /lib/dracut-lib.sh
type fsck_single >/dev/null 2>&1 || . /lib/fs-lib.sh

filtersubvol() {
    local _oldifs
    _oldifs="$IFS"
    IFS=","
    set $*
    IFS="$_oldifs"
    while [ $# -gt 0 ]; do
        case $1 in
            subvol\=*) :;;
            *) printf '%s' "${1}," ;;
        esac
        shift
    done
}

fsck_usr()
{
    local _dev=$1
    local _fs=$2
    local _fsopts=$3
    local _fsckoptions

    if [ -f "$NEWROOT"/fsckoptions ]; then
        _fsckoptions=$(cat "$NEWROOT"/fsckoptions)
    fi

    if [ -f "$NEWROOT"/forcefsck ] || getargbool 0 forcefsck ; then
        _fsckoptions="-f $_fsckoptions"
    elif [ -f "$NEWROOT"/.autofsck ]; then
        [ -f "$NEWROOT"/etc/sysconfig/autofsck ] && . "$NEWROOT"/etc/sysconfig/autofsck
        if [ "$AUTOFSCK_DEF_CHECK" = "yes" ]; then
            AUTOFSCK_OPT="$AUTOFSCK_OPT -f"
        fi
        if [ -n "$AUTOFSCK_SINGLEUSER" ]; then
            warn "*** Warning -- the system did not shut down cleanly. "
            warn "*** Dropping you to a shell; the system will continue"
            warn "*** when you leave the shell."
            emergency_shell
        fi
        _fsckoptions="$AUTOFSCK_OPT $_fsckoptions"
    fi

    fsck_single "$_dev" "$_fs" "$_fsopts" "$_fsckoptions"
}

mount_usr()
{
    local _dev _mp _fs _opts _rest _usr_found _ret _freq _passno
    # check, if we have to mount the /usr filesystem
    while read _dev _mp _fs _opts _freq _passno || [ -n "$_dev" ]; do
        [ "${_dev%%#*}" != "$_dev" ] && continue
        if [ "$_mp" = "/usr" ]; then
            case "$_dev" in
                LABEL=*)
                    _dev="$(echo $_dev | sed 's,/,\\x2f,g')"
                    _dev="/dev/disk/by-label/${_dev#LABEL=}"
                    ;;
                UUID=*)
                    _dev="${_dev#block:}"
                    _dev="/dev/disk/by-uuid/${_dev#UUID=}"
                    ;;
            esac
            if strstr "$_opts" "subvol=" && \
                [ "${root#block:}" -ef $_dev ] && \
                [ -n "$rflags" ]; then
                # for btrfs subvolumes we have to mount /usr with the same rflags
                rflags=$(filtersubvol "$rflags")
                rflags=${rflags%%,}
                _opts="${_opts:+${_opts},}${rflags}"
            elif getargbool 0 ro; then
                # if "ro" is specified, we want /usr to be mounted read-only
                _opts="${_opts:+${_opts},}ro"
            elif getargbool 0 rw; then
                # if "rw" is specified, we want /usr to be mounted read-write
                _opts="${_opts:+${_opts},}rw"
            fi
            echo "$_dev ${NEWROOT}${_mp} $_fs ${_opts} $_freq $_passno"
            _usr_found="1"
            break
        fi
    done < "$NEWROOT/etc/fstab" >> /etc/fstab

    if [ "$_usr_found" != "" ]; then
        # we have to mount /usr
        _fsck_ret=0
        if ! getargbool 0 rd.skipfsck; then
            if [ "0" != "${_passno:-0}" ]; then
                fsck_usr "$_dev" "$_fs" "$_opts"
                _fsck_ret=$?
                [ $_fsck_ret -ne 255 ] && echo $_fsck_ret >/run/initramfs/usr-fsck
            fi
        fi

        info "Mounting /usr with -o $_opts"
        mount "$NEWROOT/usr" 2>&1 | vinfo

        if ! ismounted "$NEWROOT/usr"; then
            warn "Mounting /usr to $NEWROOT/usr failed"
            warn "*** Dropping you to a shell; the system will continue"
            warn "*** when you leave the shell."
            emergency_shell
        fi
    fi
}

if [ -f "$NEWROOT/etc/fstab" ]; then
    mount_usr
fi
