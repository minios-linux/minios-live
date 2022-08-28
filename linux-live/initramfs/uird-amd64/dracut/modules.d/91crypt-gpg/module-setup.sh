#!/bin/bash

# GPG support is optional
# called by dracut
check() {
    require_binaries gpg || return 1

    if sc_requested; then
        if ! sc_supported; then
            dwarning "crypt-gpg: GnuPG >= 2.1 with scdaemon and libusb required for ccid smartcard support"
            return 1
        fi
        return 0
    fi

    return 255
}

# called by dracut
depends() {
    echo crypt
}

# called by dracut
install() {
    inst_multiple gpg
    inst "$moddir/crypt-gpg-lib.sh" "/lib/dracut-crypt-gpg-lib.sh"

    if sc_requested; then
        inst_multiple gpg-agent
        inst_multiple gpg-connect-agent
        inst_multiple /usr/libexec/scdaemon
        cp "$dracutsysrootdir$(sc_public_key)" "${initdir}/root/"
    fi
}

sc_public_key() {
    echo -n "/etc/dracut.conf.d/crypt-public-key.gpg"
}

# CCID Smartcard support requires GnuPG >= 2.1 with scdaemon and libusb
sc_supported() {
    local gpgMajor="$(gpg --version | sed -n 1p | sed -n -r -e 's|.* ([0-9]*).*|\1|p')"
    local gpgMinor="$(gpg --version | sed -n 1p | sed -n -r -e 's|.* [0-9]*\.([0-9]*).*|\1|p')"
    if [[ "${gpgMajor}" -gt 2 || "${gpgMajor}" -eq 2 && "${gpgMinor}" -ge 1 ]] && \
       require_binaries gpg-agent &&
       require_binaries gpg-connect-agent &&
       require_binaries /usr/libexec/scdaemon &&
       ($DRACUT_LDD $dracutsysrootdir/usr/libexec/scdaemon | grep libusb > /dev/null); then
        return 0
    else
        return 1
    fi
}

sc_requested() {
    if [ -f "$dracutsysrootdir$(sc_public_key)" ]; then
        return 0
    else
        return 1
    fi
}
