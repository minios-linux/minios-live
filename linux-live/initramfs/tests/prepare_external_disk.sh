#!/bin/bash
# Prepare a disposable DD image for external-module boot tests.
set -euo pipefail
[ "$(id -u)" = 0 ] || exit 77
ISO=$(readlink -f "$1")
OUT=$(readlink -f "$2")
MODE=${3:-none}
MODULE=${4:-06-firefox-amd64.sb}
SIZE=${5:-64}
PACKAGES=${6:-}
RESOURCES=${7:-}
case "$SIZE" in '' | *[!0-9]*) exit 1 ;; esac
[ "$SIZE" -ge 64 ] || exit 1
case "$MODULE" in */* | '' | .* ) exit 1 ;; esac
case "$MODE" in none | raw | raw-large | raw-badlink | native) ;; *) exit 1 ;; esac
[ -f "$ISO" ] && [ -d "$OUT" ] || exit 1
[ ! -e "$OUT/external.raw" ] || exit 1
[ ! -e "$OUT/external.qcow2" ] || exit 1
WORK=$(mktemp -d "$OUT/prepare.XXXXXX")
LOOP=""
cleanup() {
    if mountpoint -q "$WORK/mount"; then umount "$WORK/mount"; fi
    [ -z "$LOOP" ] || losetup -d "$LOOP"
    rm -rf "$WORK"
}
trap cleanup EXIT
cp --sparse=always "$ISO" "$OUT/external.raw"
truncate -s 4G "$OUT/external.raw"
printf ', +, 83\n' | sfdisk --no-reread -N 3 "$OUT/external.raw"
START=$(sfdisk --json "$OUT/external.raw" | python3 -c 'import json,sys; print(json.load(sys.stdin)["partitiontable"]["partitions"][2]["start"])')
LOOP=$(losetup --find --show --offset "$((START * 512))" "$OUT/external.raw")
mkfs.ext4 -q -F -L persistence "$LOOP"
mkdir -p "$WORK/mount" "$WORK/module/etc"
mount "$LOOP" "$WORK/mount"
mkdir -p "$WORK/mount/minios/changes" "$WORK/mount/minios/modules"
if [ -n "$PACKAGES" ]; then
    [ -d "$PACKAGES" ] || exit 1
    mkdir "$WORK/mount/packages"
    cp "$PACKAGES"/*.deb "$WORK/mount/packages/"
fi
if [ -n "$RESOURCES" ]; then
    [ -d "$RESOURCES" ] || exit 1
    mkdir "$WORK/mount/tests"
    cp -a "$RESOURCES/." "$WORK/mount/tests/"
fi
printf 'external replacement\n' >"$WORK/module/etc/minios-external-module"
mksquashfs "$WORK/module" "$WORK/mount/minios/$MODULE" -noappend -processors 1 -quiet
if [ "$MODE" != none ]; then
    STORE="$WORK/mount/minios/changes"
    mkdir -p "$WORK/session/changes/etc" "$WORK/session/workdir"
    printf 'original session\n' >"$WORK/session/changes/etc/perchtoram-session"
    for ID in 1 2; do
        mkdir "$STORE/$ID"
        if [ "$MODE" != native ]; then
            truncate -s "${SIZE}M" "$STORE/$ID/changes.img"
            mkfs.ext4 -q -F -d "$WORK/session" "$STORE/$ID/changes.img"
        else
            cp -a "$WORK/session/." "$STORE/$ID/"
        fi
        BACKEND=raw
        [ "$MODE" != native ] || BACKEND=native
        printf 'session_mode[%s]=%s\nsession_union[%s]=overlayfs\nsession_size[%s]=%s\n' "$ID" "$BACKEND" "$ID" "$ID" "$SIZE" >>"$STORE/session.conf"
    done
    printf 'default=1\n' >>"$STORE/session.conf"
    if [ "$MODE" = raw-large ]; then
        truncate -s 2G "$STORE/1/changes.img"
    elif [ "$MODE" = raw-badlink ]; then
        ln -s /missing-container-data "$STORE/2/bad-link"
    fi
fi
umount "$WORK/mount"
losetup -d "$LOOP"
LOOP=""
chmod 644 "$OUT/external.raw"
qemu-img convert -f raw -O qcow2 "$OUT/external.raw" "$OUT/external.qcow2"
chmod 644 "$OUT/external.qcow2"
printf 'Prepared %s\n' "$OUT/external.qcow2"
