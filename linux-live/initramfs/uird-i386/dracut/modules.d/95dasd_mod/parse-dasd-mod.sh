#!/bin/sh
mod_args=""

for dasd_arg in $(getargs rd.dasd= -d rd_DASD= DASD=); do
    mod_args="$mod_args,$dasd_arg"
done

mod_args="${mod_args#*,}"

if [ -x /sbin/dasd_cio_free -a -n "$mod_args" ]; then
    [ -d /etc/modprobe.d ] || mkdir -m 0755 -p /etc/modprobe.d
    echo "options dasd_mod dasd=$mod_args" >> /etc/modprobe.d/dasd_mod.conf
fi

unset dasd_arg
if [ -x /sbin/dasd_cio_free ] ; then
    dasd_cio_free
fi
