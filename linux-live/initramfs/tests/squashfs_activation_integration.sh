#!/bin/sh
set -eu

ROOT=${1:?initramfs root is required}
WORK=$(mktemp -d)
CHANGES="$WORK/changes"
SOURCE_TREE="$WORK/source"
SESSION="$WORK/sessions/1"

cleanup() {
    umount "$SOURCE_TREE" 2>/dev/null || true
    umount "$CHANGES" 2>/dev/null || true
    losetup -a 2>/dev/null | awk -F: -v work="$WORK" 'index($0, work) { print $1 }' |
        while IFS= read -r LOOP; do losetup -d "$LOOP" 2>/dev/null || true; done
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

[ "$(id -u)" -eq 0 ]
losetup --find >/dev/null 2>&1
command -v python3 >/dev/null
[ -x "$ROOT/livekit-mos/bin/mksquashfs" ]
[ -x "$ROOT/livekit-mos/bin/unsquashfs" ]
PATH="$ROOT/livekit-mos/bin:$PATH"

mkdir -p "$CHANGES" "$SOURCE_TREE/etc" "$SESSION"
truncate -s 32M "$WORK/source.img"
mke2fs -q -t ext4 -F -m 0 -O '^has_journal' "$WORK/source.img"
mount -o loop,rw,noatime "$WORK/source.img" "$SOURCE_TREE"
rmdir "$SOURCE_TREE/lost+found"
mkdir "$SOURCE_TREE/etc"
printf '%s' data >"$SOURCE_TREE/etc/config"
ln "$SOURCE_TREE/etc/config" "$SOURCE_TREE/etc/config-hard"
ln -s etc/config "$SOURCE_TREE/link"
python3 -c 'import os, sys; os.setxattr(sys.argv[1], b"user.test", b"value")' \
    "$SOURCE_TREE/etc/config"
"$ROOT/livekit-mos/bin/mksquashfs" "$SOURCE_TREE" "$SESSION/changes.sb" \
    -noappend -no-progress -exit-on-error -processors 1 -comp zstd -b 1M -xattrs
umount "$SOURCE_TREE"

DIGEST=$(sha256sum "$SESSION/changes.sb" | awk '{print $1}')
SIZE=$(wc -c <"$SESSION/changes.sb" | tr -d ' ')
FOOTPRINT='{"block_size":1048576,"compressor":"zstd","directory_count":2,"directory_entry_count":4,"filename_bytes":24,"hardlink_reference_count":1,"inode_count":4,"product_kind":"minios-extraction-footprint","regular_file_bytes":4,"regular_file_inodes":1,"schema_version":1,"symlink_count":1,"symlink_target_bytes":10,"whiteout_count":0,"xattr_count":1,"xattr_name_bytes":9,"xattr_value_bytes":5}'
CONF="$WORK/sessions/session.conf"
printf '%s\n' \
    'default=1' \
    'session_mode[1]=squashfs' \
    'session_policy[1]=manual' \
    'session_union[1]=overlayfs' \
    "session_digest[1]=$DIGEST" \
    "session_compressed[1]=$SIZE" \
    'session_uncompressed[1]=4' \
    'session_entries[1]=4' \
    'session_generation[1]=1' \
    "session_footprint[1]=$FOOTPRINT" >"$CONF"

# shellcheck source=/dev/null
. "$ROOT/livekit-mos/lib/livekitlib"
export MINIOS_UNSQUASHFS="$ROOT/livekit-mos/bin/unsquashfs"
export MINIOS_SQUASHFS_SESSION=1
export MINIOS_SQUASHFS_SESSION_DIR="$SESSION"
export MINIOS_SQUASHFS_CONF="$CONF"
export MINIOS_SQUASHFS_SYSTEM_UNION=overlayfs

squashfs_generation_restore "$CHANGES"

[ "$(cat "$CHANGES/changes/etc/config")" = data ]
[ "$(readlink "$CHANGES/changes/link")" = etc/config ]
# `ls -di` is intentionally the same inode query available in the initrd.
# shellcheck disable=SC2012
[ "$(ls -di "$CHANGES/changes/etc/config" | awk '{print $1}')" = \
  "$(ls -di "$CHANGES/changes/etc/config-hard" | awk '{print $1}')" ]
[ "$(python3 -c 'import os, sys; print(os.getxattr(sys.argv[1], b"user.test").decode())' \
    "$CHANGES/changes/etc/config")" = value ]

squashfs_upper_unwind "$CHANGES"
trap - EXIT INT TERM
rm -rf "$WORK"
