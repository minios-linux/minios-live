#!/bin/bash

# called by dracut
check() {
    require_binaries /bin/mksh
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    # If another shell is already installed, do not use mksh
    [[ -x $initdir/bin/sh ]] && return

    # Prefer mksh as /bin/sh if it is available.
    inst /bin/mksh && ln -sf mksh "${initdir}/bin/sh"
}

