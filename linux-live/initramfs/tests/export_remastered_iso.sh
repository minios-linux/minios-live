#!/bin/bash
# Read a stopped Testo disk; never attach the original qcow2 for writing.
set -euo pipefail
[ "$(id -u)" = 0 ] || exit 77
DISK=$(readlink -f "$1")
OUT=$(readlink -m "$2")
[ -f "$DISK" ] && [ ! -e "$OUT" ] && [ -d "${OUT%/*}" ] || exit 1
WORK=$(mktemp -d "${OUT%/*}/remaster-export.XXXXXX")
LOOP=""
cleanup() {
    mountpoint -q "$WORK/mount" && umount "$WORK/mount" || :
    [ -z "$LOOP" ] || losetup -d "$LOOP"
    rm -rf "$WORK"
}
trap cleanup EXIT
qemu-img convert -f qcow2 -O raw "$DISK" "$WORK/disk.raw"
START=$(sfdisk --json "$WORK/disk.raw" | python3 -c 'import json,sys; print(json.load(sys.stdin)["partitiontable"]["partitions"][2]["start"])')
LOOP=$(losetup --find --show --read-only --offset "$((START * 512))" "$WORK/disk.raw")
mkdir "$WORK/mount"
mount -o ro,noload "$LOOP" "$WORK/mount"
cp "$WORK/mount/rebuilt.iso" "$OUT"
chmod 644 "$OUT"
sha256sum "$OUT"
