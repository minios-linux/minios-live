#!/bin/bash
# Install Ventoy only on a newly-created loop-backed acceptance image.
set -euo pipefail
[ "$(id -u)" = 0 ] || exit 77
VENDOR=$(readlink -f "$1")
ISO=$(readlink -f "$2")
SOURCE=$(readlink -f "$3")
OUT=$(readlink -f "$4")
MODE=${5:-folder}
CODE_SOURCE=${6:-}
AUTOSEL=${7:-1}
case "$AUTOSEL" in 0 | 1) ;; *) exit 1 ;; esac
case "$MODE" in plain | folder | plugin) ;; *) exit 1 ;; esac
[ -f "$VENDOR/Ventoy2Disk.sh" ] && [ -f "$ISO" ] && [ -d "$OUT" ] || exit 1
[ "$MODE" != folder ] || [ -f "$SOURCE" ] || exit 1
[ ! -e "$OUT/ventoy.raw" ] && [ ! -e "$OUT/ventoy.qcow2" ] || exit 1
WORK=$(mktemp -d "$OUT/prepare.XXXXXX")
LOOP=""
SOURCELOOP=""
cleanup() {
    mountpoint -q "$WORK/target" && umount "$WORK/target" || :
    mountpoint -q "$WORK/source" && umount "$WORK/source" || :
    [ -z "$SOURCELOOP" ] || losetup -d "$SOURCELOOP"
    [ -z "$LOOP" ] || losetup -d "$LOOP"
    rm -rf "$WORK"
}
trap cleanup EXIT
truncate -s 6G "$OUT/ventoy.raw"
LOOP=$(losetup --find --show --partscan "$OUT/ventoy.raw")
printf 'y\ny\n' | bash "$VENDOR/Ventoy2Disk.sh" -I -S "$LOOP"
partprobe "$LOOP"
mkdir "$WORK/target" "$WORK/source"
mount "${LOOP}p1" "$WORK/target" || "$VENDOR/tool/x86_64/mount.exfat-fuse" "${LOOP}p1" "$WORK/target"
mkdir -p "$WORK/target/ISO" "$WORK/target/ventoy"
cp "$ISO" "$WORK/target/ISO/MiniOS.iso"
if [ "$MODE" = plugin ]; then
    if [ -n "$CODE_SOURCE" ]; then
        mkdir -p "$WORK/source/changes/usr/lib/minios-session-manager" "$WORK/source/changes/usr/bin" "$WORK/source/changes/usr/sbin"
        for FILE in minios_session.py minios_session_manager.py minios_persistence_guard.py; do
            cp "$CODE_SOURCE/minios-session-manager/lib/$FILE" "$WORK/source/changes/usr/lib/minios-session-manager/"
        done
        cp "$CODE_SOURCE/minios-tools/bin/savechanges" "$WORK/source/changes/usr/bin/"
        cp "$CODE_SOURCE/minios-live-config/frontend/minios-update-users" "$WORK/source/changes/usr/sbin/"
    fi
    truncate -s 256M "$WORK/target/ventoy/persistence.dat"
    mkfs.ext4 -q -F -L casper-rw -d "$WORK/source" "$WORK/target/ventoy/persistence.dat"
    blkid -p -s UUID -o value "$WORK/target/ventoy/persistence.dat" >"$OUT/plugin.uuid"
    printf '{"control":[{"VTOY_LINUX_REMOUNT":"1"}],"persistence":[{"image":"/ISO/MiniOS.iso","backend":"/ventoy/persistence.dat","autosel":%s}]}\n' "$AUTOSEL" >"$WORK/target/ventoy/ventoy.json"
elif [ "$MODE" = folder ]; then
    START=$(sfdisk --json "$SOURCE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["partitiontable"]["partitions"][2]["start"])')
    SOURCELOOP=$(losetup --find --show --read-only --offset "$((START * 512))" "$SOURCE")
    mount -o ro "$SOURCELOOP" "$WORK/source"
    cp -r "$WORK/source/minios" "$WORK/target/"
    printf '{"control":[{"VTOY_LINUX_REMOUNT":"1"}]}\n' >"$WORK/target/ventoy/ventoy.json"
fi
sync -f "$WORK/target"
cmp "$ISO" "$WORK/target/ISO/MiniOS.iso"
if [ "$MODE" = plain ]; then
    [ ! -e "$WORK/target/ventoy/ventoy.json" ]
else
    python3 -m json.tool "$WORK/target/ventoy/ventoy.json" >/dev/null
fi
if [ -n "$SOURCELOOP" ]; then
    umount "$WORK/source"
    losetup -d "$SOURCELOOP"
fi
SOURCELOOP=""
umount "$WORK/target"
losetup -d "$LOOP"
LOOP=""
qemu-img convert -f raw -O qcow2 "$OUT/ventoy.raw" "$OUT/ventoy.qcow2"
chmod 644 "$OUT/ventoy.qcow2"
printf 'Prepared %s\n' "$OUT/ventoy.qcow2"
