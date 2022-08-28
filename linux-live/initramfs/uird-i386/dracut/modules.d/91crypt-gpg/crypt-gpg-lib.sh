#!/bin/sh

command -v ask_for_password >/dev/null || . /lib/dracut-crypt-lib.sh

# gpg_decrypt mnt_point keypath keydev device
#
# Decrypts symmetrically encrypted (password or OpenPGP smartcard) key to standard output.
#
# mnt_point - mount point where <keydev> is already mounted
# keypath - GPG encrypted key path relative to <mnt_point>
# keydev - device on which key resides; only to display in prompt
# device - device to be opened by cryptsetup; only to display in prompt
gpg_decrypt() {
    local mntp="$1"
    local keypath="$2"
    local keydev="$3"
    local device="$4"

    local gpghome=/tmp/gnupg
    local opts="--homedir $gpghome --no-mdc-warning --skip-verify --quiet"
    opts="$opts --logger-file /dev/null --batch --no-tty --passphrase-fd 0"

    mkdir -m 0700 -p "$gpghome"

    # Setup GnuPG home and gpg-agent for usage of OpenPGP smartcard.
    # This requires GnuPG >= 2.1, as it uses the new ,,pinentry-mode´´
    # feature, which - when set to ,,loopback´´ - allows us to pipe
    # the smartcard's pin to GnuPG (instead of using a normal pinentry
    # program needed with GnuPG < 2.1), making for uncomplicated
    # integration with the existing codebase.
    local useSmartcard="0"
    local gpgMajorVersion="$(gpg --version | sed -n 1p | sed -n -r -e 's|.* ([0-9]*).*|\1|p')"
    local gpgMinorVersion="$(gpg --version | sed -n 1p | sed -n -r -e 's|.* [0-9]*\.([0-9]*).*|\1|p')"

    if [ "${gpgMajorVersion}" -ge 2 ] && [ "${gpgMinorVersion}" -ge 1 ] \
            && [ -f /root/crypt-public-key.gpg ] && getargbool 1 rd.luks.smartcard ; then
        useSmartcard="1"
        echo "allow-loopback-pinentry" >> "$gpghome/gpg-agent.conf"
        GNUPGHOME="$gpghome" gpg-agent --quiet --daemon
        GNUPGHOME="$gpghome" gpg --quiet --no-tty --import < /root/crypt-public-key.gpg
        local smartcardSerialNumber="$(GNUPGHOME=$gpghome gpg --no-tty --card-status \
            | sed -n -r -e 's|Serial number.*: ([0-9]*)|\1|p' | tr -d '\n')"
        if [ -n "${smartcardSerialNumber}" ]; then
            inputPrompt="PIN (OpenPGP card ${smartcardSerialNumber})"
        fi
        GNUPGHOME="$gpghome" gpg-connect-agent 1>/dev/null learn /bye
        opts="$opts --pinentry-mode=loopback"
    fi

    ask_for_password \
        --cmd "gpg $opts --decrypt $mntp/$keypath" \
        --prompt "${inputPrompt:-Password ($keypath on $keydev for $device)}" \
        --tries 3 --tty-echo-off

    # Clean up the smartcard gpg-agent
    if [ "${useSmartcard}" = "1" ]; then
        GNUPGHOME="$gpghome" gpg-connect-agent 1>/dev/null killagent /bye
    fi

    rm -rf -- "$gpghome"
}
