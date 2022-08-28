#!/bin/bash

# called by dracut
check() {
    require_binaries /bin/bash
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    # If another shell is already installed, do not use bash
    [[ -x $initdir/bin/sh ]] && return

    # Prefer bash as /bin/sh if it is available.
    inst /bin/bash && ln -sf bash "${initdir}/bin/sh"
}

