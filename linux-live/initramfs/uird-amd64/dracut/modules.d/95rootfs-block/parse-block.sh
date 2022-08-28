#!/bin/sh

case "$root" in
    block:LABEL=*|LABEL=*)
        root="${root#block:}"
        root="$(echo $root | sed 's,/,\\x2f,g')"
        root="block:/dev/disk/by-label/${root#LABEL=}"
        rootok=1 ;;
    block:UUID=*|UUID=*)
        root="${root#block:}"
        root="${root#UUID=}"
        root="$(echo $root | tr "[:upper:]" "[:lower:]")"
        root="block:/dev/disk/by-uuid/${root#UUID=}"
        rootok=1 ;;
    block:PARTUUID=*|PARTUUID=*)
        root="${root#block:}"
        root="${root#PARTUUID=}"
        root="$(echo $root | tr "[:upper:]" "[:lower:]")"
        root="block:/dev/disk/by-partuuid/${root}"
        rootok=1 ;;
    block:PARTLABEL=*|PARTLABEL=*)
        root="${root#block:}"
        root="block:/dev/disk/by-partlabel/${root#PARTLABEL=}"
        rootok=1 ;;
    /dev/*)
        root="block:${root}"
        rootok=1 ;;
esac

[ "${root%%:*}" = "block" ] && wait_for_dev "${root#block:}"
