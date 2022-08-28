#!/bin/sh

command -v getarg >/dev/null || . /lib/dracut-lib.sh

# check if the crypttab contains an entry for a LUKS UUID
crypttab_contains() {
    local luks="$1"
    local dev="$2"
    local l d rest
    if [ -f /etc/crypttab ]; then
        while read l d rest || [ -n "$l" ]; do
            strstr "${l##luks-}" "${luks##luks-}" && return 0
            strstr "$d" "${luks##luks-}" && return 0
            if [ -n "$dev" ]; then
                for _dev in $(devnames $d); do
                    [ "$dev" -ef "$_dev" ] && return 0
                done
            fi
            if [ -e /etc/block_uuid.map ]; then
                # search for line starting with $d
                _line=$(sed -n "\,^$d .*$,{p}" /etc/block_uuid.map)
                [ -z "$_line" ] && continue
                # get second column with uuid
                _uuid="$(echo $_line | sed 's,^.* \(.*$\),\1,')"
                strstr "$_uuid" "${luks##luks-}" && return 0
            fi
        done < /etc/crypttab
    fi
    return 1
}

# ask_for_password
#
# Wraps around plymouth ask-for-password and adds fallback to tty password ask
# if plymouth is not present.
#
# --cmd command
#   Command to execute. Required.
# --prompt prompt
#   Password prompt. Note that function already adds ':' at the end.
#   Recommended.
# --tries n
#   How many times repeat command on its failure.  Default is 3.
# --ply-[cmd|prompt|tries]
#   Command/prompt/tries specific for plymouth password ask only.
# --tty-[cmd|prompt|tries]
#   Command/prompt/tries specific for tty password ask only.
# --tty-echo-off
#   Turn off input echo before tty command is executed and turn on after.
#   It's useful when password is read from stdin.
ask_for_password() {
    local cmd; local prompt; local tries=3
    local ply_cmd; local ply_prompt; local ply_tries=3
    local tty_cmd; local tty_prompt; local tty_tries=3
    local ret

    while [ $# -gt 0 ]; do
        case "$1" in
            --cmd) ply_cmd="$2"; tty_cmd="$2"; shift;;
            --ply-cmd) ply_cmd="$2"; shift;;
            --tty-cmd) tty_cmd="$2"; shift;;
            --prompt) ply_prompt="$2"; tty_prompt="$2"; shift;;
            --ply-prompt) ply_prompt="$2"; shift;;
            --tty-prompt) tty_prompt="$2"; shift;;
            --tries) ply_tries="$2"; tty_tries="$2"; shift;;
            --ply-tries) ply_tries="$2"; shift;;
            --tty-tries) tty_tries="$2"; shift;;
            --tty-echo-off) tty_echo_off=yes;;
        esac
        shift
    done

    { flock -s 9;
        # Prompt for password with plymouth, if installed and running.
        if type plymouth >/dev/null 2>&1 && plymouth --ping 2>/dev/null; then
            plymouth ask-for-password \
                --prompt "$ply_prompt" --number-of-tries=$ply_tries \
                --command="$ply_cmd"
            ret=$?
        else
            if [ "$tty_echo_off" = yes ]; then
                stty_orig="$(stty -g)"
                stty -echo
            fi

            local i=1
            while [ $i -le $tty_tries ]; do
                [ -n "$tty_prompt" ] && \
                    printf "$tty_prompt [$i/$tty_tries]:" >&2
                eval "$tty_cmd" && ret=0 && break
                ret=$?
                i=$(($i+1))
                [ -n "$tty_prompt" ] && printf '\n' >&2
            done

            [ "$tty_echo_off" = yes ] && stty $stty_orig
        fi
    } 9>/.console_lock

    [ $ret -ne 0 ] && echo "Wrong password" >&2
    return $ret
}

# Try to mount specified device (by path, by UUID or by label) and check
# the path with 'test'.
#
# example:
# test_dev -f LABEL="nice label" /some/file1
test_dev() {
    local test_op=$1; local dev="$2"; local f="$3"
    local ret=1; local mount_point=$(mkuniqdir /mnt testdev)
    local path

    [ -n "$dev" -a -n "$*" ] || return 1
    [ -d "$mount_point" ] || die 'Mount point does not exist!'

    if mount -r "$dev" "$mount_point" >/dev/null 2>&1; then
        test $test_op "${mount_point}/${f}"
        ret=$?
        umount "$mount_point"
    fi

    rmdir "$mount_point"

    return $ret
}

# match_dev devpattern dev
#
# Returns true if 'dev' matches 'devpattern'.  Both 'devpattern' and 'dev' are
# expanded to kernel names and then compared.  If name of 'dev' is on list of
# names of devices matching 'devpattern', the test is positive.  'dev' and
# 'devpattern' may be anything which function 'devnames' recognizes.
#
# If 'devpattern' is empty or '*' then function just returns true.
#
# Example:
#   match_dev UUID=123 /dev/dm-1
# Returns true if /dev/dm-1 UUID starts with "123".
match_dev() {
    [ -z "$1" -o "$1" = '*' ] && return 0
    local devlist; local dev

    devlist="$(devnames "$1")" || return 255
    dev="$(devnames "$2")" || return 255

    strstr "
$devlist
" "
$dev
"
}

# getkey keysfile for_dev
#
# Reads file <keysfile> produced by probe-keydev and looks for first line to
# which device <for_dev> matches.  The successful result is printed in format
# "<keydev>:<keypath>".  When nothing found, just false is returned.
#
# Example:
#   getkey /tmp/luks.keys /dev/sdb1
# May print:
#   /dev/sdc1:/keys/some.key
getkey() {
    local keys_file="$1"; local for_dev="$2"
    local luks_dev; local key_dev; local key_path

    [ -z "$keys_file" -o -z "$for_dev" ] && die 'getkey: wrong usage!'
    [ -f "$keys_file" ] || return 1

    local IFS=:
    while read luks_dev key_dev key_path || [ -n "$luks_dev" ]; do
        if match_dev "$luks_dev" "$for_dev"; then
            echo "${key_dev}:${key_path}"
            return 0
        fi
    done < "$keys_file"

    return 1
}

# readkey keypath keydev device
#
# Mounts <keydev>, reads key from file <keypath>, optionally processes it (e.g.
# if encrypted with GPG) and prints to standard output which is supposed to be
# read by cryptsetup.  <device> is just passed to helper function for
# informational purpose.
readkey() {
    local keypath="$1"
    local keydev="$2"
    local device="$3"

    # No mounting needed if the keyfile resides inside the initrd
    if [ "/" = "$keydev" ]; then
        local mntp=/
    else
        # This creates a unique single mountpoint for *, or several for explicitly
        # given LUKS devices. It accomplishes unlocking multiple LUKS devices with
        # a single password entry.
        local mntp="/mnt/$(str_replace "keydev-$keydev-$keypath" '/' '-')"

        if [ ! -d "$mntp" ]; then
            mkdir "$mntp"
            mount -r "$keydev" "$mntp" || die 'Mounting rem. dev. failed!'
        fi
    fi

    case "${keypath##*.}" in
        gpg)
            if [ -f /lib/dracut-crypt-gpg-lib.sh ]; then
                . /lib/dracut-crypt-gpg-lib.sh
                gpg_decrypt "$mntp" "$keypath" "$keydev" "$device"
            else
                die "No GPG support to decrypt '$keypath' on '$keydev'."
            fi
            ;;
        img)
            if [ -f /lib/dracut-crypt-loop-lib.sh ]; then
                . /lib/dracut-crypt-loop-lib.sh
                loop_decrypt "$mntp" "$keypath" "$keydev" "$device"
                printf "%s\n" "umount \"$mntp\"; rmdir \"$mntp\";" > ${hookdir}/cleanup/"crypt-loop-cleanup-99-${mntp##*/}".sh
                return 0
            else
                die "No loop file support to decrypt '$keypath' on '$keydev'."
            fi
            ;;
        *) cat "$mntp/$keypath" ;;
    esac

    # No unmounting if the keyfile resides inside the initrd
    if [ "/" != "$keydev" ]; then
        # General unmounting mechanism, modules doing custom cleanup should return earlier
        # and install a pre-pivot cleanup hook
        umount "$mntp"
        rmdir "$mntp"
    fi
}
