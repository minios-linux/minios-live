#!/bin/bash --norc
#
# Copyright 2009 Red Hat, Inc.  All rights reserved.
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


dwarning() {
    echo "Warning: $@" >&2
}

dinfo() {
    [[ $beverbose ]] && echo "$@" >&2
}

derror() {
    echo "Error: $@" >&2
}

usage() {
#                                                       80x25 linebreak here ^
    cat << EOF
Usage: $0 [OPTION]... <initramfs> <base image> [<image>...]
Creates initial ramdisk image by concatenating several images from the command
line and /boot/dracut/

  -f, --force           Overwrite existing initramfs file.
  -i, --imagedir        Directory with additional images to add
                        (default: /boot/dracut/)
  -o, --overlaydir      Overlay directory, which contains files that
                        will be used to create an additional image
  --nooverlay           Do not use the overlay directory
  --noimagedir          Do not use the additional image directory
  -h, --help            This message
  --debug               Output debug information of the build process
  -v, --verbose         Verbose output during the build process
EOF
}


imagedir=/boot/dracut/
overlay=/var/lib/dracut/overlay

while (($# > 0)); do
    case $1 in
        -f|--force) force=yes;;
        -i|--imagedir) imagedir=$2;shift;;
        -o|--overlaydir) overlay=$2;shift;;
        --nooverlay) no_overlay=yes;shift;;
        --noimagedir) no_imagedir=yes;shift;;
        -h|--help) usage; exit 1 ;;
        --debug) debug="yes";;
        -v|--verbose) beverbose="yes";;
        -*) printf "\nUnknown option: %s\n\n" "$1" >&2; usage; exit 1;;
        *) break ;;
    esac
    shift
done

outfile=$1; shift

if [[ -z $outfile ]]; then
    derror "No output file specified."
    usage
    exit 1
fi

baseimage=$1; shift

if [[ -z $baseimage ]]; then
    derror "No base image specified."
    usage
    exit 1
fi

if [[ -f $outfile && ! $force ]]; then
    derror "Will not override existing initramfs ($outfile) without --force"
    exit 1
fi

if [[ ! $no_imagedir && ! -d $imagedir ]]; then
    derror "Image directory $overlay is not a directory"
    exit 1
fi

if [[ ! $no_overlay && ! -d $overlay ]]; then
    derror "Overlay $overlay is not a directory"
    exit 1
fi

if [[ ! $no_overlay ]]; then
    ofile="$imagedir/90-overlay.img"
    dinfo "Creating image $ofile from directory $overlay"
    type pigz &>/dev/null && gzip=pigz || gzip=gzip
    ( cd "$overlay"; find . |cpio --quiet -H newc -o |$gzip -9 > "$ofile"; )
fi

if [[ ! $no_imagedir ]]; then
    for i in "$imagedir/"*.img; do
        [[ -f $i ]] && images+=("$i")
    done
fi

images+=($@)

dinfo "Using base image $baseimage"
cat -- "$baseimage" > "$outfile"

for i in "${images[@]}"; do
    dinfo "Appending $i"
    cat -- "$i" >> "$outfile"
done

dinfo "Created $outfile"

exit 0
