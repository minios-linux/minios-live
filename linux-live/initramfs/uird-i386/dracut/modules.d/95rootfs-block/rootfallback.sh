#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

for root in $(getargs rootfallback=); do
    case "$root" in
        block:LABEL=*|LABEL=*)
            root="${root#block:}"
            root="$(echo $root | sed 's,/,\\x2f,g')"
            root="/dev/disk/by-label/${root#LABEL=}"
            ;;
        block:UUID=*|UUID=*)
            root="${root#block:}"
            root="${root#UUID=}"
            root="$(echo $root | tr "[:upper:]" "[:lower:]")"
            root="/dev/disk/by-uuid/${root#UUID=}"
            ;;
        block:PARTUUID=*|PARTUUID=*)
            root="${root#block:}"
            root="${root#PARTUUID=}"
            root="$(echo $root | tr "[:upper:]" "[:lower:]")"
            root="/dev/disk/by-partuuid/${root}"
            ;;
        block:PARTLABEL=*|PARTLABEL=*)
            root="${root#block:}"
            root="/dev/disk/by-partlabel/${root#PARTLABEL=}"
            ;;
    esac

    if ! [ -b "$root" ]; then
        warn "Could not find rootfallback $root"
        continue
    fi

    if mount "$root" /sysroot; then
        info "Mounted rootfallback $root"
        exit 0
    else
        warn "Failed to mount rootfallback $root"
        exit 1
    fi
done

[ -e "$job" ] && rm -f "$job"
