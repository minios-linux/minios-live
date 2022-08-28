#!/bin/bash
#
# Copyright 2005-2010 Harald Hoyer <harald@redhat.com>
# Copyright 2005-2010 Red Hat, Inc.  All rights reserved.
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

usage()
{
    {
        echo "Usage: ${0##*/} [options] [<initramfs file> [<filename> [<filename> [...] ]]]"
        echo "Usage: ${0##*/} [options] -k <kernel version>"
        echo
        echo "-h, --help                  print a help message and exit."
        echo "-s, --size                  sort the contents of the initramfs by size."
        echo "-m, --mod                   list modules."
        echo "-f, --file <filename>       print the contents of <filename>."
        echo "--unpack                    unpack the initramfs, instead of displaying the contents."
        echo "                            If optional filenames are given, will only unpack specified files,"
        echo "                            else the whole image will be unpacked. Won't unpack anything from early cpio part."
        echo "--unpackearly               unpack the early microcode part of the initramfs."
        echo "                            Same as --unpack, but only unpack files from early cpio part."
        echo "-v, --verbose               unpack verbosely."
        echo "-k, --kver <kernel version> inspect the initramfs of <kernel version>."
        echo
    } >&2
}


[[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut

sorted=0
modules=0
unset verbose
declare -A filenames

unset POSIXLY_CORRECT
TEMP=$(getopt \
    -o "vshmf:k:" \
    --long kver: \
    --long file: \
    --long mod \
    --long help \
    --long size \
    --long unpack \
    --long unpackearly \
    --long verbose \
    -- "$@")

if (( $? != 0 )); then
    usage
    exit 1
fi

eval set -- "$TEMP"

while (($# > 0)); do
    case $1 in
        -k|--kver)     KERNEL_VERSION="$2"; shift;;
        -f|--file)     filenames[${2#/}]=1; shift;;
        -s|--size)     sorted=1;;
        -h|--help)     usage; exit 0;;
        -m|--mod)      modules=1;;
        -v|--verbose)  verbose="--verbose";;
        --unpack)      unpack=1;;
        --unpackearly) unpackearly=1;;
        --)            shift;break;;
        *)             usage; exit 1;;
    esac
    shift
done

[[ $KERNEL_VERSION ]] || KERNEL_VERSION="$(uname -r)"

if [[ $1 ]]; then
    image="$1"
    if ! [[ -f "$image" ]]; then
        {
            echo "$image does not exist"
            echo
        } >&2
        usage
        exit 1
    fi
else
    [[ -f /etc/machine-id ]] && read MACHINE_ID < /etc/machine-id

    if [[ -d /boot/loader/entries || -L /boot/loader/entries ]] \
        && [[ $MACHINE_ID ]] \
        && [[ -d /boot/${MACHINE_ID} || -L /boot/${MACHINE_ID} ]] ; then
        image="/boot/${MACHINE_ID}/${KERNEL_VERSION}/initrd"
    else
        image="/boot/initramfs-${KERNEL_VERSION}.img"
    fi
fi

shift
while (($# > 0)); do
    filenames[${1#/}]=1;
    shift
done

if ! [[ -f "$image" ]]; then
    {
        echo "No <initramfs file> specified and the default image '$image' cannot be accessed!"
        echo
    } >&2
    usage
    exit 1
fi

TMPDIR="$(mktemp -d -t lsinitrd.XXXXXX)"
trap "rm -rf '$TMPDIR'" EXIT

dracutlibdirs() {
    for d in lib64/dracut lib/dracut usr/lib64/dracut usr/lib/dracut; do
        echo "$d/$1"
    done
}

extract_files()
{
    (( ${#filenames[@]} == 1 )) && nofileinfo=1
    for f in "${!filenames[@]}"; do
        [[ $nofileinfo ]] || echo "initramfs:/$f"
        [[ $nofileinfo ]] || echo "========================================================================"
        $CAT "$image" 2>/dev/null | cpio --extract --verbose --quiet --to-stdout "$f" 2>/dev/null
        ((ret+=$?))
        [[ $nofileinfo ]] || echo "========================================================================"
        [[ $nofileinfo ]] || echo
    done
}

list_modules()
{
    echo "dracut modules:"
    $CAT "$image" | cpio --extract --verbose --quiet --to-stdout -- \
        $(dracutlibdirs modules.txt) 2>/dev/null
    ((ret+=$?))
}

list_files()
{
    echo "========================================================================"
    if [ "$sorted" -eq 1 ]; then
        $CAT "$image" 2>/dev/null | cpio --extract --verbose --quiet --list | sort -n -k5
    else
        $CAT "$image" 2>/dev/null | cpio --extract --verbose --quiet --list | sort -k9
    fi
    ((ret+=$?))
    echo "========================================================================"
}

list_squash_content()
{
    SQUASH_IMG="squash/root.img"
    SQUASH_TMPFILE="$TMPDIR/initrd.root.sqsh"

    $CAT "$image" 2>/dev/null | cpio --extract --verbose --quiet --to-stdout -- \
        $SQUASH_IMG > "$SQUASH_TMPFILE" 2>/dev/null
    if [[ -s $SQUASH_TMPFILE ]]; then
        echo "Squashed content ($SQUASH_IMG):"
        echo "========================================================================"
        unsquashfs -ll "$SQUASH_TMPFILE" | tail -n +4
        echo "========================================================================"
    fi
}

unpack_files()
{
    if (( ${#filenames[@]} > 0 )); then
        for f in "${!filenames[@]}"; do
            $CAT "$image" 2>/dev/null | cpio -id --quiet $verbose $f
            ((ret+=$?))
        done
    else
        $CAT "$image" 2>/dev/null | cpio -id --quiet $verbose
        ((ret+=$?))
    fi
}

read -N 2 bin < "$image"
if [ "$bin" = "MZ" ]; then
    command -v objcopy > /dev/null || { echo "Need 'objcopy' to unpack an UEFI executable."; exit 1; }
    objcopy \
        --dump-section .linux="$TMPDIR/vmlinuz" \
        --dump-section .initrd="$TMPDIR/initrd.img" \
        --dump-section .cmdline="$TMPDIR/cmdline.txt" \
        --dump-section .osrel="$TMPDIR/osrel.txt" \
        "$image" /dev/null
    uefi="$image"
    image="$TMPDIR/initrd.img"
    [ -f "$image" ] || exit 1
fi

if (( ${#filenames[@]} <= 0 )) && [[ -z "$unpack" ]] && [[ -z "$unpackearly" ]]; then
    if [ -n $uefi ]; then
        echo -n "initrd in UEFI: $uefi: "
        du -h $image | while read a b || [ -n "$a" ]; do echo $a;done
        if [ -f "$TMPDIR/osrel.txt" ]; then
            name=$(sed -En '/^PRETTY_NAME/ s/^\w+=["'"'"']?([^"'"'"'$]*)["'"'"']?/\1/p' "$TMPDIR/osrel.txt")
            id=$(sed -En '/^ID/ s/^\w+=["'"'"']?([^"'"'"'$]*)["'"'"']?/\1/p' "$TMPDIR/osrel.txt")
            build=$(sed -En '/^BUILD_ID/ s/^\w+=["'"'"']?([^"'"'"'$]*)["'"'"']?/\1/p' "$TMPDIR/osrel.txt")
            echo "OS Release: $name (${id}-${build})"
        fi
        if [ -f "$TMPDIR/vmlinuz" ]; then
            version=$(strings -n 20 "$TMPDIR/vmlinuz" | sed -En '/[0-9]+\.[0-9]+\.[0-9]+/ { p; q 0 }')
            echo "Kernel Version: $version"
        fi
        if [ -f "$TMPDIR/cmdline.txt" ]; then
            echo "Command line:"
            sed -En 's/\s+/\n/g; s/\x00/\n/; p' "$TMPDIR/cmdline.txt"
        fi
    else
        echo -n "Image: $image: "
        du -h $image | while read a b || [ -n "$a" ]; do echo $a;done
    fi

    echo "========================================================================"
fi

read -N 6 bin < "$image"
case $bin in
    $'\x71\xc7'*|070701)
        CAT="cat --"
        is_early=$(cpio --extract --verbose --quiet --to-stdout -- 'early_cpio' < "$image" 2>/dev/null)
        # Debian mkinitramfs does not create the file 'early_cpio', so let's check if firmware files exist
        [[ "$is_early" ]] || is_early=$(cpio --list --verbose --quiet --to-stdout -- 'kernel/*/microcode/*.bin' < "$image" 2>/dev/null)
        if [[ "$is_early" ]]; then
            if [[ -n "$unpack" ]]; then
                # should use --unpackearly for early CPIO
                :
            elif [[ -n "$unpackearly" ]]; then
                unpack_files
            elif (( ${#filenames[@]} > 0 )); then
                extract_files
            else
                echo "Early CPIO image"
                list_files
            fi
            if [[ -d "$dracutbasedir/skipcpio" ]]; then
                SKIP="$dracutbasedir/skipcpio/skipcpio"
            else
                SKIP="$dracutbasedir/skipcpio"
            fi
            if ! [[ -x $SKIP ]]; then
                echo
                echo "'$SKIP' not found, cannot display remaining contents!" >&2
                echo
                exit 0
            fi
        fi
        ;;
esac

if [[ $SKIP ]] ; then
    bin="$($SKIP "$image" | { read -N 6 bin && echo "$bin" ; })"
else
    read -N 6 bin < "$image"
fi
case $bin in
    $'\x1f\x8b'*)
        CAT="zcat --"
        ;;
    BZh*)
        CAT="bzcat --"
        ;;
    $'\x71\xc7'*|070701)
        CAT="cat --"
        ;;
    $'\x02\x21'*)
        CAT="lz4 -d -c"
        ;;
    $'\x89'LZO$'\0'*)
        CAT="lzop -d -c"
        ;;
    $'\x28\xB5\x2F\xFD'*)
        CAT="zstd -d -c"
        ;;
    *)
        if echo "test"|xz|xzcat --single-stream >/dev/null 2>&1; then
            CAT="xzcat --single-stream --"
        else
            CAT="xzcat --"
        fi
        ;;
esac

skipcpio()
{
    $SKIP "$@" | $ORIG_CAT
}

if [[ $SKIP ]]; then
    ORIG_CAT="$CAT"
    CAT=skipcpio
fi

if (( ${#filenames[@]} > 1 )); then
    TMPFILE="$TMPDIR/initrd.cpio"
    $CAT "$image" 2>/dev/null > $TMPFILE
    pre_decompress()
    {
        cat $TMPFILE
    }
    CAT=pre_decompress
fi

ret=0

if [[ -n "$unpack" ]]; then
    unpack_files
elif (( ${#filenames[@]} > 0 )); then
    extract_files
else
    version=$($CAT "$image" | cpio --extract --verbose --quiet --to-stdout -- \
        $(dracutlibdirs 'dracut-*') 2>/dev/null)
    ((ret+=$?))
    echo "Version: $version"
    echo
    if [ "$modules" -eq 1 ]; then
        list_modules
        echo "========================================================================"
    else
        echo -n "Arguments: "
        $CAT "$image" | cpio --extract --verbose --quiet --to-stdout -- \
            $(dracutlibdirs build-parameter.txt) 2>/dev/null
        echo
        list_modules
        list_files
        list_squash_content
    fi
fi

exit $ret
