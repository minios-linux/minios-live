#!/bin/bash
# module-setup for url-lib

# called by dracut
check() {
    require_binaries curl || return 1
    return 255
}

# called by dracut
depends() {
    echo network
    return 0
}

# called by dracut
install() {
    local _dir _crt _found _lib _nssckbi _p11roots _p11root _p11item
    inst_simple "$moddir/url-lib.sh" "/lib/url-lib.sh"
    inst_multiple -o ctorrent
    inst_multiple curl
    # also install libs for curl https
    inst_libdir_file "libnsspem.so*"
    inst_libdir_file "libnsssysinit.so*"
    inst_libdir_file "libsoftokn3.so*"
    inst_libdir_file "libsqlite3.so*"

    for _dir in $libdirs; do
	[[ -d $dracutsysrootdir$_dir ]] || continue
        for _lib in $dracutsysrootdir$_dir/libcurl.so.*; do
	    [[ -e $_lib ]] || continue
            [[ $_nssckbi ]] || _nssckbi=$(grep -F --binary-files=text -z libnssckbi $_lib)
            _crt=$(grep -F --binary-files=text -z .crt $_lib)
            [[ $_crt ]] || continue
            [[ $_crt == /*/* ]] || continue
            if ! inst "${_crt#$dracutsysrootdir}"; then
                dwarn "Couldn't install '$_crt' SSL CA cert bundle; HTTPS might not work."
                continue
            fi
            _found=1
        done
    done
    # If we found no cert bundle files referenced in libcurl but we
    # *did* find a mention of libnssckbi (checked above), install it.
    # If its truly NSS libnssckbi, it includes its own trust bundle,
    # but if it's really p11-kit-trust.so, we need to find the dirs
    # where it will look for a trust bundle and install them too.
    if ! [[ $_found ]] && [[ $_nssckbi ]] ; then
        _found=1
        inst_libdir_file "libnssckbi.so*" || _found=
        for _dir in $libdirs; do
            [[ -e $dracutsysrootdir$_dir/libnssckbi.so ]] || continue
            # this looks for directory-ish strings in the file
            for _p11roots in $(grep -o --binary-files=text "/[[:alpha:]][[:print:]]*" $dracutsysrootdir$_dir/libnssckbi.so) ; do
                # the string can be a :-separated list of dirs
                for _p11root in $(echo "$_p11roots" | tr ':' '\n') ; do
                    # check if it's actually a directory (there are
                    # several false positives in the results)
                    [[ -d "$dracutsysrootdir$_p11root" ]] || continue
                    # check if it has some specific subdirs that all
                    # p11-kit trust dirs have
                    [[ -d "$dracutsysrootdir${_p11root}/anchors" ]] || continue
                    [[ -d "$dracutsysrootdir${_p11root}/blacklist" ]] || continue
                    # so now we know it's really a p11-kit trust dir;
                    # install everything in it
                    for _p11item in $(find "$dracutsysrootdir$_p11root") ; do
                        if ! inst "${_p11item#$dracutsysrootdir}" ; then
                            dwarn "Couldn't install '${_p11item#$dracutsysrootdir}' from p11-kit trust dir '${_p11root#$dracutsysrootdir}'; HTTPS might not work."
                            continue
                        fi
                    done
                done
            done
        done
    fi
    [[ $_found ]] || dwarn "Couldn't find SSL CA cert bundle or libnssckbi.so; HTTPS won't work."
}

