#!/bin/sh
#
# Licensed under the GPLv2+
#
# Copyright 2008-2010, Red Hat, Inc.
# Harald Hoyer <harald@redhat.com>

PATH=/usr/sbin:/usr/bin:/sbin:/bin

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

while [ $# -gt 0 ]; do
    case "$1" in
        --onetime)
            onetime="yes";;
        --online)
            qname="/online";;
        --settled)
            qname="/settled";;
        --finished)
            qname="/finished";;
        --timeout)
            qname="/timeout";;
        --unique)
            unique="yes";;
        --name)
            name="$2";shift;;
        --env)
            env="$2"; shift;;
        *)
            break;;
    esac
    shift
done

if [ -z "$unique" ]; then
    job="${name}$$"
else
    job="${name:-$1}"
    job=${job##*/}
fi

exe=$1
shift

[ -x "$exe" ] || exe=$(command -v $exe)
if [ -z "$exe" ] ; then
    echo "Invalid command"
    exit 1
fi

{
    [ -n "$onetime" ] && echo '[ -e "$job" ] && rm -f -- "$job"'
    [ -n "$env" ] && echo "$env"
    echo "$exe" "$@"
} > "/tmp/$$-${job}.sh"

mv -f "/tmp/$$-${job}.sh" "$hookdir/initqueue${qname}/${job}.sh"
[ -z "$qname" ] && >> $hookdir/initqueue/work
exit 0
