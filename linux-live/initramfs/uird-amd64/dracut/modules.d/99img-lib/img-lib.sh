#!/bin/sh
# img-lib.sh: utilities for dealing with archives and filesystem images.
#
# TODO: identify/unpack rpm, deb, maybe others?


# super-simple "file" that only identifies archives.
# works with stdin if $1 is not set.
det_archive() {
    # NOTE: echo -e works in ash and bash, but not dash
    local bz="BZh" xz="$(echo -e '\xfd7zXZ')" gz="$(echo -e '\x1f\x8b')" zs="$(echo -e '\x28\xB5\x2F\xFD')"
    local headerblock="$(dd ${1:+if=$1} bs=262 count=1 2>/dev/null)"
    case "$headerblock" in
        $xz*) echo "xz" ;;
        $gz*) echo "gzip" ;;
        $bz*) echo "bzip2" ;;
        $zs*) echo "zstd" ;;
        07070*) echo "cpio" ;;
        *ustar) echo "tar" ;;
    esac
}

# determine filesystem type for a filesystem image
det_fs_img() {
    local dev=$(losetup --find --show "$1") rv=""
    det_fs $dev; rv=$?
    losetup -d $dev
    return $rv
}

# unpack_archive ARCHIVE OUTDIR
# unpack a (possibly compressed) cpio/tar archive
unpack_archive() {
    local img="$1" outdir="$2" archiver="" decompr=""
    local ft="$(det_archive $img)"
    case "$ft" in
        xz|gzip|bzip2|zstd) decompr="$ft -dc" ;;
        cpio|tar) decompr="cat";;
        *) return 1 ;;
    esac
    ft="$($decompr $img | det_archive)"
    case "$ft" in
        cpio) archiver="cpio -iumd" ;;
        tar) archiver="tar -xf -" ;;
        *) return 2 ;;
    esac
    mkdir -p $outdir
    ( cd $outdir; $decompr | $archiver 2>/dev/null ) < $img
}

# unpack_fs FSIMAGE OUTDIR
# unpack a filesystem image
unpack_fs() {
    local img="$1" outdir="$2" mnt="$(mkuniqdir /tmp unpack_fs.)"
    mount -o loop $img $mnt || { rmdir $mnt; return 1; }
    mkdir -p $outdir; outdir="$(cd $outdir; pwd)"
    copytree $mnt $outdir
    umount $mnt
    rmdir $mnt
}

# unpack an image file - compressed/uncompressed cpio/tar, filesystem, whatever
# unpack_img IMAGEFILE OUTDIR
unpack_img() {
    local img="$1" outdir="$2"
    [ -r "$img" ] || { warn "can't read img!"; return 1; }
    [ -n "$outdir" ] || { warn "unpack_img: no output dir given"; return 1; }

    if [ "$(det_archive $img)" ]; then
        unpack_archive "$@" || { warn "can't unpack archive file!"; return 1; }
    else
        unpack_fs "$@" || { warn "can't unpack filesystem image!"; return 1; }
    fi
}
