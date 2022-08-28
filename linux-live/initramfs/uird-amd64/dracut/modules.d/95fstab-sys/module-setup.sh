#!/bin/bash

# called by dracut
check() {
    test -f $dracutsysrootdir/etc/fstab.sys || [[ -n $add_fstab  ||  -n $fstab_lines ]]
}

# called by dracut
depends() {
    echo fs-lib
}

# called by dracut
install() {
    [ -f $dracutsysrootdir/etc/fstab.sys ] && inst_simple /etc/fstab.sys
    inst_hook pre-pivot 00 "$moddir/mount-sys.sh"
}
