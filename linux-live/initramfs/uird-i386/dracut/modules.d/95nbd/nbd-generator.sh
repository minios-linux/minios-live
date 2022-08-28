#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

[ -z "$root" ] && root=$(getarg root=)

[ "${root%%:*}" = "nbd" ] || exit 0

GENERATOR_DIR="$2"
[ -z "$GENERATOR_DIR" ] && exit 1

[ -d "$GENERATOR_DIR" ] || mkdir "$GENERATOR_DIR"

ROOTFLAGS="$(getarg rootflags)"

nroot=${root#nbd:}
nbdserver=${nroot%%:*}; nroot=${nroot#*:}
nbdport=${nroot%%:*}; nroot=${nroot#*:}
nbdfstype=${nroot%%:*}; nroot=${nroot#*:}
nbdflags=${nroot%%:*}

if [ "$nbdflags" = "$nbdfstype" ]; then
    unset nbdflags
fi
if [ "$nbdfstype" = "$nbdport" ]; then
    unset nbdfstype
fi

[ -n "$nbdflags" ] && ROOTFLAGS="$nbdflags"

if getarg "ro"; then
    if [ -n "$ROOTFLAGS" ]; then
        ROOTFLAGS="$ROOTFLAGS,ro"
    else
        ROOTFLAGS="ro"
    fi
fi

if [ -n "$nbdfstype" ]; then
    ROOTFSTYPE="$nbdfstype"
else
    ROOTFSTYPE=$(getarg rootfstype=) || unset ROOTFSTYPE
fi

{
    echo "[Unit]"
    echo "Before=initrd-root-fs.target"
    echo "[Mount]"
    echo "Where=/sysroot"
    echo "What=/dev/root"
    [ -n "$ROOTFSTYPE" ] && echo "Type=${ROOTFSTYPE}"
    [ -n "$ROOTFLAGS" ] && echo "Options=${ROOTFLAGS}"
} > "$GENERATOR_DIR"/sysroot.mount

exit 0
