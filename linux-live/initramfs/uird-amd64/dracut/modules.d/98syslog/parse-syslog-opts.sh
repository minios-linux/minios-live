#!/bin/sh

# Parses the syslog commandline options
#
#Bootparameters:
#syslogserver=ip    Where to syslog to
#sysloglevel=level  What level has to be logged
#syslogtype=rsyslog|syslog|syslogng
#                   Don't auto detect syslog but set it
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

detect_syslog() {
    syslogtype=""
    if [ -e /sbin/rsyslogd ]; then
        syslogtype="rsyslogd"
    elif [ -e /sbin/syslogd ]; then
        syslogtype="syslogd"
    elif [ -e /sbin/syslog-ng ]; then
        syslogtype="syslog-ng"
    else
        warn "Could not find any syslog binary although the syslogmodule is selected to be installed. Please check."
    fi
    echo "$syslogtype"
    [ -n "$syslogtype" ]
}

syslogserver=$(getarg syslog.server -d syslog)
syslogfilters=$(getargs syslog.filter -d filter)
syslogtype=$(getarg syslog.type -d syslogtype)

[ -n "$syslogserver" ] && echo $syslogserver > /tmp/syslog.server
[ -n "$syslogfilters" ] && echo "$syslogfilters" > /tmp/syslog.filters
if [ -n "$syslogtype" ]; then
    echo "$syslogtype" > /tmp/syslog.type
else
    syslogtype=$(detect_syslog)
    echo $syslogtype > /tmp/syslog.type
fi
