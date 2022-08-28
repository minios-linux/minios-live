#!/bin/sh

if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2>/dev/null
fi
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

[ -f /usr/lib/initrd-release ] && . /usr/lib/initrd-release
[ -n "$VERSION" ] && info "dracut-$VERSION"

if ! getargbool 1 'rd.hostonly'; then
    [ -f /etc/cmdline.d/99-cmdline-ask.conf ] && mv /etc/cmdline.d/99-cmdline-ask.conf /tmp/99-cmdline-ask.conf
    remove_hostonly_files
    [ -f /tmp/99-cmdline-ask.conf ] && mv /tmp/99-cmdline-ask.conf /etc/cmdline.d/99-cmdline-ask.conf
fi

info "Using kernel command line parameters:" $(getcmdline)

getargbool 0 rd.udev.log-priority=info -d rd.udev.info -d -n -y rdudevinfo && echo 'udev_log="info"' >> /etc/udev/udev.conf
getargbool 0 rd.udev.log-priority=debug -d rd.udev.debug -d -n -y rdudevdebug && echo 'udev_log="debug"' >> /etc/udev/udev.conf

source_conf /etc/conf.d

# Get the "root=" parameter from the kernel command line, but differentiate
# between the case where it was set to the empty string and the case where it
# wasn't specified at all.
if ! root="$(getarg root=)"; then
    root_unset='UNSET'
fi

rflags="$(getarg rootflags=)"
getargbool 0 ro && rflags="${rflags},ro"
getargbool 0 rw && rflags="${rflags},rw"
rflags="${rflags#,}"

fstype="$(getarg rootfstype=)"
if [ -z "$fstype" ]; then
    fstype="auto"
fi

export root
export rflags
export fstype

make_trace_mem "hook cmdline" '1+:mem' '1+:iomem' '3+:slab' '4+:komem'
# run scriptlets to parse the command line
getarg 'rd.break=cmdline' -d 'rdbreak=cmdline' && emergency_shell -n cmdline "Break before cmdline"
source_hook cmdline

[ -f /lib/dracut/parse-resume.sh ] && . /lib/dracut/parse-resume.sh

case "${root}${root_unset}" in
    block:LABEL=*|LABEL=*)
        root="${root#block:}"
        root="$(echo $root | sed 's,/,\\x2f,g')"
        root="block:/dev/disk/by-label/${root#LABEL=}"
        rootok=1 ;;
    block:UUID=*|UUID=*)
        root="${root#block:}"
        root="block:/dev/disk/by-uuid/${root#UUID=}"
        rootok=1 ;;
    block:PARTUUID=*|PARTUUID=*)
        root="${root#block:}"
        root="block:/dev/disk/by-partuuid/${root#PARTUUID=}"
        rootok=1 ;;
    block:PARTLABEL=*|PARTLABEL=*)
        root="${root#block:}"
        root="block:/dev/disk/by-partlabel/${root#PARTLABEL=}"
        rootok=1 ;;
    /dev/*)
        root="block:${root}"
        rootok=1 ;;
    UNSET|gpt-auto)
        # systemd's gpt-auto-generator handles this case.
        rootok=1 ;;
esac

[ -z "${root}${root_unset}" ] && die "Empty root= argument"
[ -z "$rootok" ] && die "Don't know how to handle 'root=$root'"

export root rflags fstype netroot NEWROOT

export -p > /dracut-state.sh

exit 0
