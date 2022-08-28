#!/bin/bash

# called by dracut
check() {
    # do not add this module by default
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    local _i
    local _installs
    if type -P rsyslogd >/dev/null; then
        _installs="rsyslogd"
        inst_libdir_file rsyslog/lmnet.so rsyslog/imklog.so rsyslog/imuxsock.so rsyslog/imjournal.so
    elif type -P syslogd >/dev/null; then
        _installs="syslogd"
    elif type -P syslog-ng >/dev/null; then
        _installs="syslog-ng"
    else
        derror "Could not find any syslog binary although the syslogmodule" \
            "is selected to be installed. Please check."
    fi
    if [ -n "$_installs" ]; then
        inst_multiple cat $_installs
        inst_hook cmdline  90 "$moddir/parse-syslog-opts.sh"
        inst_hook cleanup 99 "$moddir/syslog-cleanup.sh"
        inst_hook initqueue/online 70 "$moddir/rsyslogd-start.sh"
        inst_simple "$moddir/rsyslogd-stop.sh" /sbin/rsyslogd-stop
        mkdir -m 0755 -p ${initdir}/etc/templates
        inst_simple "${moddir}/rsyslog.conf" /etc/templates/rsyslog.conf
    fi
    dracut_need_initqueue
}

