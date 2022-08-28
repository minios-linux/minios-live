#!/bin/bash

# fixme: assume user is root

# called by dracut
check() {
    [[ $mount_needs ]] && return 1

    # If our prerequisites are not met, fail.
    require_binaries ssh scp  || return 1

    if [[ $sshkey ]]; then
        [ ! -f $dracutsysrootdir$sshkey ] && {
            derror "ssh key: $sshkey is not found!"
            return 1
        }
    fi

    return 255
}

# called by dracut
depends() {
    # We depend on network modules being loaded
    echo network
}

inst_sshenv()
{
    if [ -d $dracutsysrootdir/root/.ssh ]; then
        inst_dir /root/.ssh
        chmod 700 ${initdir}/root/.ssh
    fi

    # Copy over ssh key and knowhosts if needed
    [[ $sshkey ]] && {
        inst_simple $sshkey
        [[ -f $dracutsysrootdir/root/.ssh/known_hosts ]] && inst_simple /root/.ssh/known_hosts
        [[ -f $dracutsysrootdir/etc/ssh/ssh_known_hosts ]] && inst_simple /etc/ssh/ssh_known_hosts
    }

    # Copy over root and system-wide ssh configs.
    [[ -f $dracutsysrootdir/root/.ssh/config ]] && inst_simple /root/.ssh/config
    if [[ -f $dracutsysrootdir/etc/ssh/ssh_config ]]; then
        inst_simple /etc/ssh/ssh_config
        sed -i -e 's/\(^[[:space:]]*\)ProxyCommand/\1# ProxyCommand/' ${initdir}/etc/ssh/ssh_config
        while read key val || [ -n "$key" ]; do
            if [[ $key == "GlobalKnownHostsFile" ]]; then
                inst_simple "$val"
            # Copy customized UserKnowHostsFile
            elif [[ $key == "UserKnownHostsFile" ]]; then
                # Make sure that ~/foo will be copied as /root/foo in kdump's initramfs
                if str_starts "$val" "~/"; then
                    val="/root/${val#"~/"}"
                fi
                inst_simple "$val"
            fi
        done < $dracutsysrootdir/etc/ssh/ssh_config
    fi

    return 0
}

# called by dracut
install() {
    local _nsslibs

    inst_multiple ssh scp
    inst_sshenv

    _nsslibs=$(
        sed -e 's/#.*//; s/^[^:]*://; s/\[[^]]*\]//' \
            $dracutsysrootdir/etc/nsswitch.conf \
        |  tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|')
    _nsslibs=${_nsslibs#|}
    _nsslibs=${_nsslibs%|}

    inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'
}

