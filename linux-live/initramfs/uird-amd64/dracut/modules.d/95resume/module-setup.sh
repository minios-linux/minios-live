#!/bin/bash

# called by dracut
check() {
    # Only support resume if hibernation is currently on
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        [[ "$(cat /sys/power/resume)" == "0:0" ]] && return 255
    }

    return 0
}

# called by dracut
cmdline() {
    local _resume

    for dev in "${!host_fs_types[@]}"; do
        [[ ${host_fs_types[$dev]} =~ ^(swap|swsuspend|swsupend)$ ]] || continue
        _resume=$(shorten_persistent_dev "$(get_persistent_dev "$dev")")
        [[ -n ${_resume} ]] && printf " resume=%s" "${_resume}"
    done
}

# called by dracut
install() {
    local _bin

    if [[ $hostonly_cmdline == "yes" ]]; then
	local _resumeconf=$(cmdline)
	[[ $_resumeconf ]] && printf "%s\n" "$_resumeconf" >> "${initdir}/etc/cmdline.d/95resume.conf"
    fi

    # if systemd is included and has the hibernate-resume tool, use it and nothing else
    if dracut_module_included "systemd" && [[ -x $dracutsysrootdir$systemdutildir/systemd-hibernate-resume ]]; then
        inst_multiple -o \
                      $systemdutildir/system-generators/systemd-hibernate-resume-generator \
                      $systemdsystemunitdir/systemd-hibernate-resume@.service \
                      $systemdutildir/systemd-hibernate-resume
        return 0
    fi

    # Optional uswsusp support
    for _bin in /usr/sbin/resume /usr/lib/suspend/resume /usr/lib/uswsusp/resume
    do
        [[ -x "$dracutsysrootdir${_bin}" ]] && {
            inst "${_bin}" /usr/sbin/resume
            [[ $hostonly ]] && [[ -f $dracutsysrootdir/etc/suspend.conf ]] && inst -H /etc/suspend.conf
            break
        }
    done

    if ! dracut_module_included "systemd"; then
        inst_hook cmdline 10 "$moddir/parse-resume.sh"
    else
        inst_script "$moddir/parse-resume.sh" /lib/dracut/parse-resume.sh
    fi

    inst_script  "$moddir/resume.sh" /lib/dracut/resume.sh
}

