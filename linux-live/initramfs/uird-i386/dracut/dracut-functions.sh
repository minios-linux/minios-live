#!/bin/bash
#
# functions used by dracut and other tools.
#
# Copyright 2005-2009 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
export LC_MESSAGES=C

# is_func <command>
# Check whether $1 is a function.
is_func() {
    [[ "$(type -t "$1")" = "function" ]]
}


# Generic substring function.  If $2 is in $1, return 0.
strstr() { [[ $1 = *"$2"* ]]; }
# Generic glob matching function. If glob pattern $2 matches anywhere in $1, OK
strglobin() { [[ $1 = *$2* ]]; }
# Generic glob matching function. If glob pattern $2 matches all of $1, OK
strglob() { [[ $1 = $2 ]]; }
# returns OK if $1 contains literal string $2 at the beginning, and isn't empty
str_starts() { [ "${1#"$2"*}" != "$1" ]; }
# returns OK if $1 contains literal string $2 at the end, and isn't empty
str_ends() { [ "${1%*"$2"}" != "$1" ]; }

# find a binary.  If we were not passed the full path directly,
# search in the usual places to find the binary.
find_binary() {
    local _delim
    local l
    local p
    [[ -z ${1##/*} ]] || _delim="/"

    if [[ "$1" == *.so* ]]; then
        for l in libdirs ; do
            if { $DRACUT_LDD "$dracutsysrootdir$l$_delim$1" &>/dev/null; };  then
                printf "%s\n" "$1"
                return 0
            fi
        done
        if { $DRACUT_LDD "$dracutsysrootdir$_delim$1" &>/dev/null; }; then
            printf "%s\n" "$1"
            return 0
        fi
    fi
    if [[ "$1" == */* ]]; then
        if [[ -L $dracutsysrootdir$_delim$1 ]] || [[ -x $dracutsysrootdir$_delim$1 ]]; then
            printf "%s\n" "$1"
            return 0
        fi
    fi
    for p in $DRACUT_PATH ; do
        if [[ -L $dracutsysrootdir$p$_delim$1 ]] || [[ -x $dracutsysrootdir$p$_delim$1 ]];  then
            printf "%s\n" "$1"
            return 0
        fi
    done

    [[ -n "$dracutsysrootdir" ]] && return 1
    type -P "${1##*/}"
}

ldconfig_paths()
{
    $DRACUT_LDCONFIG ${dracutsysrootdir:+-r ${dracutsysrootdir} -f /etc/ld.so.conf} -pN 2>/dev/null | grep -E -v '/(lib|lib64|usr/lib|usr/lib64)/[^/]*$' | sed -n 's,.* => \(.*\)/.*,\1,p' | sort | uniq
}

# Version comparision function.  Assumes Linux style version scheme.
# $1 = version a
# $2 = comparision op (gt, ge, eq, le, lt, ne)
# $3 = version b
vercmp() {
    local _n1=(${1//./ }) _op=$2 _n2=(${3//./ }) _i _res

    for ((_i=0; ; _i++))
    do
        if [[ ! ${_n1[_i]}${_n2[_i]} ]]; then _res=0
        elif ((${_n1[_i]:-0} > ${_n2[_i]:-0})); then _res=1
        elif ((${_n1[_i]:-0} < ${_n2[_i]:-0})); then _res=2
        else continue
        fi
        break
    done

    case $_op in
        gt) ((_res == 1));;
        ge) ((_res != 2));;
        eq) ((_res == 0));;
        le) ((_res != 1));;
        lt) ((_res == 2));;
        ne) ((_res != 0));;
    esac
}

# Create all subdirectories for given path without creating the last element.
# $1 = path
mksubdirs() {
    [[ -e ${1%/*} ]] || mkdir -m 0755 -p -- "${1%/*}"
}

# Function prints global variables in format name=value line by line.
# $@ = list of global variables' name
print_vars() {
    local _var _value

    for _var in "$@"
    do
        eval printf -v _value "%s" \""\$$_var"\"
        [[ ${_value} ]] && printf '%s="%s"\n' "$_var" "$_value"
    done
}

# normalize_path <path>
# Prints the normalized path, where it removes any duplicated
# and trailing slashes.
# Example:
# $ normalize_path ///test/test//
# /test/test
normalize_path() {
    shopt -q -s extglob
    set -- "${1//+(\/)//}"
    shopt -q -u extglob
    printf "%s\n" "${1%/}"
}

# convert_abs_rel <from> <to>
# Prints the relative path, when creating a symlink to <to> from <from>.
# Example:
# $ convert_abs_rel /usr/bin/test /bin/test-2
# ../../bin/test-2
# $ ln -s $(convert_abs_rel /usr/bin/test /bin/test-2) /usr/bin/test
convert_abs_rel() {
    local __current __absolute __abssize __cursize __newpath
    local -i __i __level

    set -- "$(normalize_path "$1")" "$(normalize_path "$2")"

    # corner case #1 - self looping link
    [[ "$1" == "$2" ]] && { printf "%s\n" "${1##*/}"; return; }

    # corner case #2 - own dir link
    [[ "${1%/*}" == "$2" ]] && { printf ".\n"; return; }

    IFS="/" __current=($1)
    IFS="/" __absolute=($2)

    __abssize=${#__absolute[@]}
    __cursize=${#__current[@]}

    while [[ "${__absolute[__level]}" == "${__current[__level]}" ]]
    do
        (( __level++ ))
        if (( __level > __abssize || __level > __cursize ))
        then
            break
        fi
    done

    for ((__i = __level; __i < __cursize-1; __i++))
    do
        if ((__i > __level))
        then
            __newpath=$__newpath"/"
        fi
        __newpath=$__newpath".."
    done

    for ((__i = __level; __i < __abssize; __i++))
    do
        if [[ -n $__newpath ]]
        then
            __newpath=$__newpath"/"
        fi
        __newpath=$__newpath${__absolute[__i]}
    done

    printf "%s\n" "$__newpath"
}


# get_fs_env <device>
# Get and the ID_FS_TYPE variable from udev for a device.
# Example:
# $ get_fs_env /dev/sda2
# ext4
get_fs_env() {
    [[ $1 ]] || return
    unset ID_FS_TYPE
    ID_FS_TYPE=$(blkid -u filesystem -o export -- "$1" \
        | while read line || [ -n "$line" ]; do
            if [[ "$line" == TYPE\=* ]]; then
                printf "%s" "${line#TYPE=}";
                exit 0;
            fi
            done)
    if [[ $ID_FS_TYPE ]]; then
        printf "%s" "$ID_FS_TYPE"
        return 0
    fi
    return 1
}

# get_maj_min <device>
# Prints the major and minor of a device node.
# Example:
# $ get_maj_min /dev/sda2
# 8:2
get_maj_min() {
    local _majmin
    _majmin="$(stat -L -c '%t:%T' "$1" 2>/dev/null)"
    printf "%s" "$((0x${_majmin%:*})):$((0x${_majmin#*:}))"
}


# get_devpath_block <device>
# get the DEVPATH in /sys of a block device
get_devpath_block() {
    local _majmin _i
    _majmin=$(get_maj_min "$1")

    for _i in /sys/block/*/dev /sys/block/*/*/dev; do
        [[ -e "$_i" ]] || continue
        if [[ "$_majmin" == "$(<"$_i")" ]]; then
            printf "%s" "${_i%/dev}"
            return 0
        fi
    done
    return 1
}

# get a persistent path from a device
get_persistent_dev() {
    local i _tmp _dev _pol

    _dev=$(get_maj_min "$1")
    [ -z "$_dev" ] && return

    if [[ -n "$persistent_policy" ]]; then
	_pol="/dev/disk/${persistent_policy}/*"
    else
	_pol=
    fi

    for i in \
        $_pol \
        /dev/mapper/* \
        /dev/disk/by-uuid/* \
        /dev/disk/by-label/* \
        /dev/disk/by-partuuid/* \
        /dev/disk/by-partlabel/* \
        /dev/disk/by-id/* \
        /dev/disk/by-path/* \
        ; do
        [[ -e "$i" ]] || continue
        [[ $i == /dev/mapper/control ]] && continue
        [[ $i == /dev/mapper/mpath* ]] && continue
        _tmp=$(get_maj_min "$i")
        if [ "$_tmp" = "$_dev" ]; then
            printf -- "%s" "$i"
            return
        fi
    done
    printf -- "%s" "$1"
}

expand_persistent_dev() {
    local _dev=$1

    case "$_dev" in
        LABEL=*)
            _dev="/dev/disk/by-label/${_dev#LABEL=}"
            ;;
        UUID=*)
            _dev="${_dev#UUID=}"
            _dev="${_dev,,}"
            _dev="/dev/disk/by-uuid/${_dev}"
            ;;
        PARTUUID=*)
            _dev="${_dev#PARTUUID=}"
            _dev="${_dev,,}"
            _dev="/dev/disk/by-partuuid/${_dev}"
            ;;
        PARTLABEL=*)
            _dev="/dev/disk/by-partlabel/${_dev#PARTLABEL=}"
            ;;
    esac
    printf "%s" "$_dev"
}

shorten_persistent_dev() {
    local _dev="$1"
    case "$_dev" in
        /dev/disk/by-uuid/*)
            printf "%s" "UUID=${_dev##*/}";;
        /dev/disk/by-label/*)
            printf "%s" "LABEL=${_dev##*/}";;
        /dev/disk/by-partuuid/*)
            printf "%s" "PARTUUID=${_dev##*/}";;
        /dev/disk/by-partlabel/*)
            printf "%s" "PARTLABEL=${_dev##*/}";;
        *)
            printf "%s" "$_dev";;
    esac
}

# find_block_device <mountpoint>
# Prints the major and minor number of the block device
# for a given mountpoint.
# Unless $use_fstab is set to "yes" the functions
# uses /proc/self/mountinfo as the primary source of the
# information and only falls back to /etc/fstab, if the mountpoint
# is not found there.
# Example:
# $ find_block_device /usr
# 8:4
find_block_device() {
    local _dev _majmin _find_mpt
    _find_mpt="$1"
    if [[ $use_fstab != yes ]]; then
        [[ -d $_find_mpt/. ]]
        findmnt -e -v -n -o 'MAJ:MIN,SOURCE' --target "$_find_mpt" | { \
            while read _majmin _dev || [ -n "$_dev" ]; do
                if [[ -b $_dev ]]; then
                    if ! [[ $_majmin ]] || [[ $_majmin == 0:* ]]; then
                        _majmin=$(get_maj_min $_dev)
                    fi
                    if [[ $_majmin ]]; then
                        printf "%s\n" "$_majmin"
                    else
                        printf "%s\n" "$_dev"
                    fi
                    return 0
                fi
                if [[ $_dev = *:* ]]; then
                    printf "%s\n" "$_dev"
                    return 0
                fi
            done; return 1; } && return 0
    fi
    # fall back to /etc/fstab

    findmnt -e --fstab -v -n -o 'MAJ:MIN,SOURCE' --target "$_find_mpt" | { \
        while read _majmin _dev || [ -n "$_dev" ]; do
            if ! [[ $_dev ]]; then
                _dev="$_majmin"
                unset _majmin
            fi
            if [[ -b $_dev ]]; then
                [[ $_majmin ]] || _majmin=$(get_maj_min $_dev)
                if [[ $_majmin ]]; then
                    printf "%s\n" "$_majmin"
                else
                    printf "%s\n" "$_dev"
                fi
                return 0
            fi
            if [[ $_dev = *:* ]]; then
                printf "%s\n" "$_dev"
                return 0
            fi
        done; return 1; } && return 0

    return 1
}

# find_mp_fstype <mountpoint>
# Echo the filesystem type for a given mountpoint.
# /proc/self/mountinfo is taken as the primary source of information
# and /etc/fstab is used as a fallback.
# No newline is appended!
# Example:
# $ find_mp_fstype /;echo
# ext4
find_mp_fstype() {
    local _fs

    if [[ $use_fstab != yes ]]; then
        findmnt -e -v -n -o 'FSTYPE' --target "$1" | { \
            while read _fs || [ -n "$_fs" ]; do
                [[ $_fs ]] || continue
                [[ $_fs = "autofs" ]] && continue
                printf "%s" "$_fs"
                return 0
            done; return 1; } && return 0
    fi

    findmnt --fstab -e -v -n -o 'FSTYPE' --target "$1" | { \
        while read _fs || [ -n "$_fs" ]; do
            [[ $_fs ]] || continue
            [[ $_fs = "autofs" ]] && continue
            printf "%s" "$_fs"
            return 0
        done; return 1; } && return 0

    return 1
}

# find_dev_fstype <device>
# Echo the filesystem type for a given device.
# /proc/self/mountinfo is taken as the primary source of information
# and /etc/fstab is used as a fallback.
# No newline is appended!
# Example:
# $ find_dev_fstype /dev/sda2;echo
# ext4
find_dev_fstype() {
    local _find_dev _fs
    _find_dev="$1"
    if ! [[ "$_find_dev" = /dev* ]]; then
        [[ -b "/dev/block/$_find_dev" ]] && _find_dev="/dev/block/$_find_dev"
    fi

    if [[ $use_fstab != yes ]]; then
        findmnt -e -v -n -o 'FSTYPE' --source "$_find_dev" | { \
            while read _fs || [ -n "$_fs" ]; do
                [[ $_fs ]] || continue
                [[ $_fs = "autofs" ]] && continue
                printf "%s" "$_fs"
                return 0
            done; return 1; } && return 0
    fi

    findmnt --fstab -e -v -n -o 'FSTYPE' --source "$_find_dev" | { \
        while read _fs || [ -n "$_fs" ]; do
            [[ $_fs ]] || continue
            [[ $_fs = "autofs" ]] && continue
            printf "%s" "$_fs"
            return 0
        done; return 1; } && return 0

    return 1
}

# find_mp_fsopts <mountpoint>
# Echo the filesystem options for a given mountpoint.
# /proc/self/mountinfo is taken as the primary source of information
# and /etc/fstab is used as a fallback.
# No newline is appended!
# Example:
# $ find_mp_fsopts /;echo
# rw,relatime,discard,data=ordered
find_mp_fsopts() {
    if [[ $use_fstab != yes ]]; then
        findmnt -e -v -n -o 'OPTIONS' --target "$1" 2>/dev/null && return 0
    fi

    findmnt --fstab -e -v -n -o 'OPTIONS' --target "$1"
}

# find_dev_fsopts <device>
# Echo the filesystem options for a given device.
# /proc/self/mountinfo is taken as the primary source of information
# and /etc/fstab is used as a fallback.
# Example:
# $ find_dev_fsopts /dev/sda2
# rw,relatime,discard,data=ordered
find_dev_fsopts() {
    local _find_dev _opts
    _find_dev="$1"
    if ! [[ "$_find_dev" = /dev* ]]; then
        [[ -b "/dev/block/$_find_dev" ]] && _find_dev="/dev/block/$_find_dev"
    fi

    if [[ $use_fstab != yes ]]; then
        findmnt -e -v -n -o 'OPTIONS' --source "$_find_dev" 2>/dev/null && return 0
    fi

    findmnt --fstab -e -v -n -o 'OPTIONS' --source "$_find_dev"
}


# finds the major:minor of the block device backing the root filesystem.
find_root_block_device() { find_block_device /; }

# for_each_host_dev_fs <func>
# Execute "<func> <dev> <filesystem>" for every "<dev> <fs>" pair found
# in ${host_fs_types[@]}
for_each_host_dev_fs()
{
    local _func="$1"
    local _dev
    local _ret=1

    [[ "${#host_fs_types[@]}" ]] || return 2


    for _dev in "${!host_fs_types[@]}"; do
        $_func "$_dev" "${host_fs_types[$_dev]}" && _ret=0
    done
    return $_ret
}

host_fs_all()
{
    printf "%s\n" "${host_fs_types[@]}"
}

# Walk all the slave relationships for a given block device.
# Stop when our helper function returns success
# $1 = function to call on every found block device
# $2 = block device in major:minor format
check_block_and_slaves() {
    local _x
    [[ -b /dev/block/$2 ]] || return 1 # Not a block device? So sorry.
    if ! lvm_internal_dev $2; then "$1" $2 && return; fi
    check_vol_slaves "$@" && return 0
    if [[ -f /sys/dev/block/$2/../dev ]] && [[ /sys/dev/block/$2/../subsystem -ef /sys/class/block ]]; then
        check_block_and_slaves $1 $(<"/sys/dev/block/$2/../dev") && return 0
    fi
    [[ -d /sys/dev/block/$2/slaves ]] || return 1
    for _x in /sys/dev/block/$2/slaves/*; do
        [[ -f $_x/dev ]] || continue
        [[ $_x/subsystem -ef /sys/class/block ]] || continue
        check_block_and_slaves $1 $(<"$_x/dev") && return 0
    done
    return 1
}

check_block_and_slaves_all() {
    local _x _ret=1
    [[ -b /dev/block/$2 ]] || return 1 # Not a block device? So sorry.
    if ! lvm_internal_dev $2 && "$1" $2; then
        _ret=0
    fi
    check_vol_slaves_all "$@" && return 0
    if [[ -f /sys/dev/block/$2/../dev ]] && [[ /sys/dev/block/$2/../subsystem -ef /sys/class/block ]]; then
        check_block_and_slaves_all $1 $(<"/sys/dev/block/$2/../dev") && _ret=0
    fi
    [[ -d /sys/dev/block/$2/slaves ]] || return 1
    for _x in /sys/dev/block/$2/slaves/*; do
        [[ -f $_x/dev ]] || continue
        [[ $_x/subsystem -ef /sys/class/block ]] || continue
        check_block_and_slaves_all $1 $(<"$_x/dev") && _ret=0
    done
    return $_ret
}
# for_each_host_dev_and_slaves <func>
# Execute "<func> <dev>" for every "<dev>" found
# in ${host_devs[@]} and their slaves
for_each_host_dev_and_slaves_all()
{
    local _func="$1"
    local _dev
    local _ret=1

    [[ "${host_devs[@]}" ]] || return 2

    for _dev in "${host_devs[@]}"; do
        [[ -b "$_dev" ]] || continue
        if check_block_and_slaves_all $_func $(get_maj_min $_dev); then
            _ret=0
        fi
    done
    return $_ret
}

for_each_host_dev_and_slaves()
{
    local _func="$1"
    local _dev

    [[ "${host_devs[@]}" ]] || return 2

    for _dev in "${host_devs[@]}"; do
        [[ -b "$_dev" ]] || continue
        check_block_and_slaves $_func $(get_maj_min $_dev) && return 0
    done
    return 1
}

# ugly workaround for the lvm design
# There is no volume group device,
# so, there are no slave devices for volume groups.
# Logical volumes only have the slave devices they really live on,
# but you cannot create the logical volume without the volume group.
# And the volume group might be bigger than the devices the LV needs.
check_vol_slaves() {
    local _lv _vg _pv _dm _majmin
    _majmin="$2"
    _lv="/dev/block/$_majmin"
    _dm=/sys/dev/block/$_majmin/dm
    [[ -f $_dm/uuid  && $(<$_dm/uuid) =~ LVM-* ]] || return 1
    _vg=$(dmsetup splitname --noheadings -o vg_name $(<"$_dm/name") )
    # strip space
    _vg="${_vg//[[:space:]]/}"
    if [[ $_vg ]]; then
        for _pv in $(lvm vgs --noheadings -o pv_name "$_vg" 2>/dev/null)
        do
            check_block_and_slaves $1 $(get_maj_min $_pv) && return 0
        done
    fi
    return 1
}

check_vol_slaves_all() {
    local _lv _vg _pv _majmin
    _majmin="$2"
    _lv="/dev/block/$_majmin"
    _dm="/sys/dev/block/$_majmin/dm"
    [[ -f $_dm/uuid  && $(<$_dm/uuid) =~ LVM-* ]] || return 1
    _vg=$(dmsetup splitname --noheadings -o vg_name $(<"$_dm/name") )
    # strip space
    _vg="${_vg//[[:space:]]/}"
    if [[ $_vg ]]; then
        # when filter/global_filter is set, lvm may be failed
        lvm lvs --noheadings -o vg_name $_vg 2>/dev/null 1>/dev/null
        if [ $? -ne 0 ]; then
             return 1
        fi

        for _pv in $(lvm vgs --noheadings -o pv_name "$_vg" 2>/dev/null)
        do
            check_block_and_slaves_all $1 $(get_maj_min $_pv)
        done
        return 0
    fi
    return 1
}



# fs_get_option <filesystem options> <search for option>
# search for a specific option in a bunch of filesystem options
# and return the value
fs_get_option() {
    local _fsopts=$1
    local _option=$2
    local OLDIFS="$IFS"
    IFS=,
    set -- $_fsopts
    IFS="$OLDIFS"
    while [ $# -gt 0 ]; do
        case $1 in
            $_option=*)
                echo ${1#${_option}=}
                break
        esac
        shift
    done
}

check_kernel_config()
{
    local _config_opt="$1"
    local _config_file
    [[ -f $dracutsysrootdir/boot/config-$kernel ]] \
        && _config_file="/boot/config-$kernel"
    [[ -f $dracutsysrootdir/lib/modules/$kernel/config ]] \
        && _config_file="/lib/modules/$kernel/config"

    # no kernel config file, so return true
    [[ $_config_file ]] || return 0

    grep -q -F "${_config_opt}=" "$_config_file" && return 0
    return 1
}


# get_cpu_vendor
# Only two values are returned: AMD or Intel
get_cpu_vendor ()
{
    if grep -qE AMD /proc/cpuinfo; then
        printf "AMD"
    fi
    if grep -qE Intel /proc/cpuinfo; then
        printf "Intel"
    fi
}

# get_host_ucode
# Get the hosts' ucode file based on the /proc/cpuinfo
get_ucode_file ()
{
    local family=`grep -E "cpu family" /proc/cpuinfo | head -1 | sed s/.*:\ //`
    local model=`grep -E "model" /proc/cpuinfo |grep -v name | head -1 | sed s/.*:\ //`
    local stepping=`grep -E "stepping" /proc/cpuinfo | head -1 | sed s/.*:\ //`

    if [[ "$(get_cpu_vendor)" == "AMD" ]]; then
        if [[ $family -ge 21 ]]; then
            printf "microcode_amd_fam%xh.bin" $family
        else
            printf "microcode_amd.bin"
        fi
    fi
    if [[ "$(get_cpu_vendor)" == "Intel" ]]; then
        # The /proc/cpuinfo are in decimal.
        printf "%02x-%02x-%02x" ${family} ${model} ${stepping}
    fi
}

# Not every device in /dev/mapper should be examined.
# If it is an LVM device, touch only devices which have /dev/VG/LV symlink.
lvm_internal_dev() {
    local dev_dm_dir=/sys/dev/block/$1/dm
    [[ ! -f $dev_dm_dir/uuid || $(<$dev_dm_dir/uuid) != LVM-* ]] && return 1 # Not an LVM device
    local DM_VG_NAME DM_LV_NAME DM_LV_LAYER
    eval $(dmsetup splitname --nameprefixes --noheadings --rows "$(<$dev_dm_dir/name)" 2>/dev/null)
    [[ ${DM_VG_NAME} ]] && [[ ${DM_LV_NAME} ]] || return 0 # Better skip this!
    [[ ${DM_LV_LAYER} ]] || [[ ! -L /dev/${DM_VG_NAME}/${DM_LV_NAME} ]]
}

btrfs_devs() {
    local _mp="$1"
    btrfs device usage "$_mp" \
        | while read _dev _rest; do
        str_starts "$_dev" "/" || continue
        _dev=${_dev%,}
        printf -- "%s\n" "$_dev"
        done
}
