#!/bin/bash

# called by dracut
install() {
    local _terminfodir
    # terminfo bits make things work better if you fall into interactive mode
    for _terminfodir in /lib/terminfo /etc/terminfo /usr/share/terminfo; do
        [ -f $dracutsysrootdir${_terminfodir}/l/linux ] && break
    done

    if [ -d $dracutsysrootdir${_terminfodir} ]; then
        for i in "l/linux" "v/vt100" "v/vt102" "v/vt220"; do
            inst_dir "$_terminfodir/${i%/*}"
            $DRACUT_CP -L -t "${initdir}/${_terminfodir}/${i%/*}" "$dracutsysrootdir$_terminfodir/$i"
        done
    fi
}
