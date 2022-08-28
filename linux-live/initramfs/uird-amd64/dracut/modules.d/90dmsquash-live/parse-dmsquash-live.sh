#!/bin/sh
# live images are specified with
# root=live:backingdev

[ -z "$root" ] && root=$(getarg root=)

# support legacy syntax of passing liveimg and then just the base root
if getargbool 0 rd.live.image -d -y liveimg; then
    liveroot="live:$root"
fi

if [ "${root%%:*}" = "live" ] ; then
    liveroot=$root
fi

[ "${liveroot%%:*}" = "live" ] || return 1

modprobe -q loop

case "$liveroot" in
    live:LABEL=*|LABEL=*) \
        root="${root#live:}"
        root="${root//\//\\x2f}"
        root="live:/dev/disk/by-label/${root#LABEL=}"
        rootok=1 ;;
    live:CDLABEL=*|CDLABEL=*) \
        root="${root#live:}"
        root="${root//\//\\x2f}"
        root="live:/dev/disk/by-label/${root#CDLABEL=}"
        rootok=1 ;;
    live:UUID=*|UUID=*) \
        root="${root#live:}"
        root="live:/dev/disk/by-uuid/${root#UUID=}"
        rootok=1 ;;
    live:PARTUUID=*|PARTUUID=*) \
        root="${root#live:}"
        root="live:/dev/disk/by-partuuid/${root#PARTUUID=}"
        rootok=1 ;;
    live:PARTLABEL=*|PARTLABEL=*) \
        root="${root#live:}"
        root="live:/dev/disk/by-partlabel/${root#PARTLABEL=}"
        rootok=1 ;;
    live:/*.[Ii][Ss][Oo]|/*.[Ii][Ss][Oo])
        root="${root#live:}"
        root="liveiso:${root}"
        rootok=1 ;;
    live:/dev/*)
        rootok=1 ;;
    live:/*.[Ii][Mm][Gg]|/*.[Ii][Mm][Gg])
        [ -f "${root#live:}" ] && rootok=1 ;;
esac

[ "$rootok" = "1" ] || return 1

info "root was $liveroot, is now $root"

# make sure that init doesn't complain
[ -z "$root" ] && root="live"

wait_for_dev -n /dev/root

return 0
