#!/bin/bash

is_mpath() {
    local _dev=$1
    [ -e /sys/dev/block/$_dev/dm/uuid ] || return 1
    [[ $(cat /sys/dev/block/$_dev/dm/uuid) =~ mpath- ]] && return 0
    return 1
}

majmin_to_mpath_dev() {
    local _dev
    for i in /dev/mapper/*; do
        [[ $i == /dev/mapper/control ]] && continue
        _dev=$(get_maj_min $i)
        if [ "$_dev" = "$1" ]; then
            echo $i
            return
        fi
    done
}

# called by dracut
check() {
    local _rootdev

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for_each_host_dev_and_slaves is_mpath || return 255
    }

    # if there's no multipath binary, no go.
    require_binaries multipath || return 1
    require_binaries kpartx || return 1

    return 0
}

# called by dracut
depends() {
    echo rootfs-block
    echo dm
    return 0
}

# called by dracut
cmdline() {
    for m in scsi_dh_alua scsi_dh_emc scsi_dh_rdac dm_multipath; do
        if grep -m 1 -q "$m" /proc/modules ; then
            printf 'rd.driver.pre=%s ' "$m"
        fi
    done
}

# called by dracut
installkernel() {
    local _ret
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local _funcs='scsi_register_device_handler|dm_dirty_log_type_register|dm_register_path_selector|dm_register_target'
    local _s390

    if [ "$_arch" = "s390" -o "$_arch" = "s390x" ]; then
        _s390drivers="=drivers/s390/scsi"
    fi

    hostonly='' dracut_instmods -o -s "$_funcs" "=drivers/scsi" "=drivers/md" ${_s390drivers:+"$_s390drivers"}
}

# called by dracut
install() {
    local _f _allow

    add_hostonly_mpath_conf() {
        is_mpath $1 && {
            local _dev

            _dev=$(majmin_to_mpath_dev $1)
            [ -z "$_dev" ] && return
            strstr "$_allow" "$_dev" && return
            _allow="$_allow --allow $_dev"
        }
    }

    inst_multiple -o  \
        dmsetup \
        kpartx \
        mpath_wait \
        multipath  \
        multipathd \
        mpathpersist \
        xdrgetuid \
        xdrgetprio \
        /etc/xdrdevices.conf \
        /etc/multipath.conf \
        /etc/multipath/* \
        /etc/multipath/conf.d/*

    [[ $hostonly ]] && [[ $hostonly_mode = "strict" ]] && {
        for_each_host_dev_and_slaves_all add_hostonly_mpath_conf
        [ -n "$_allow" ] && mpathconf $_allow --outfile ${initdir}/etc/multipath.conf
    }

    inst $(command -v partx) /sbin/partx

    inst_libdir_file "libmultipath*" "multipath/*"
    inst_libdir_file 'libgcc_s.so*'

    if [[ $hostonly_cmdline ]] ; then
        local _conf=$(cmdline)
        [[ $_conf ]] && echo "$_conf" >> "${initdir}/etc/cmdline.d/90multipath.conf"
    fi

    if dracut_module_included "systemd"; then
        inst_simple "${moddir}/multipathd.service" "${systemdsystemunitdir}/multipathd.service"
        systemctl -q --root "$initdir" enable multipathd.service
    else
        inst_hook pre-trigger 02 "$moddir/multipathd.sh"
        inst_hook cleanup   02 "$moddir/multipathd-stop.sh"
    fi

    inst_hook cleanup   80 "$moddir/multipathd-needshutdown.sh"
    inst_hook shutdown  20 "$moddir/multipath-shutdown.sh"

    inst_rules 40-multipath.rules 56-multipath.rules \
	62-multipath.rules 65-multipath.rules \
	66-kpartx.rules 67-kpartx-compat.rules \
	11-dm-mpath.rules
}

