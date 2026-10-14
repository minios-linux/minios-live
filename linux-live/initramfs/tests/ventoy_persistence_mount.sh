#!/bin/bash
# Exercise two ready ext4 images through the actual device-mapper and OverlayFS.
set -euo pipefail
[ "$(id -u)" = 0 ] || exit 77
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
LOOP=""
MAPPED=false
cleanup() {
    mountpoint -q "$WORK/union" && umount "$WORK/union" || :
    mountpoint -q "$WORK/upper" && umount "$WORK/upper" || :
    mountpoint -q "$WORK/backend" && umount "$WORK/backend" || :
    if [ "$MAPPED" = true ]; then dmsetup remove vtoy_persistent; fi
    [ -z "$LOOP" ] || losetup -d "$LOOP"
    rm -rf "$WORK"
}
trap cleanup EXIT
dmsetup info vtoy_persistent >/dev/null 2>&1 && exit 77
export MINIOS_VENTOY_DIR="$WORK/ventoy"
export MINIOS_VENTOY_PERCH_ROOT="$WORK/backend"
export MINIOS_PERSISTENCE_RUNDIR="$WORK/state"
export MINIOS_CMDLINE_FILE="$WORK/cmdline"
export MINIOS_PERCH_ROOT_FILE="$WORK/perch-root"
export MINIOS_PERCH_STORE_FILE="$WORK/perch-store"
mkdir -p "$WORK/ventoy" "$WORK/backend" "$WORK/upper" "$WORK/union" "$WORK/bundles/00-core"
mkdir -p "$WORK/iso/minios"
: >"$WORK/ventoy/ventoy_os_param"
printf 'perchdir=resume union=overlayfs toram perchtoram=full\n' >"$WORK/cmdline"
printf 'base\n' >"$WORK/bundles/00-core/deleted"
. "$ROOT/livekit-mos/lib/livekitlib"
set +u
debug_log() { :; }
echo_white_star() { :; }
get_union_fs() { printf 'overlayfs\n'; }
refresh_devs() { :; }
for IMAGE in A B; do
    truncate -s 128M "$WORK/$IMAGE.dat"
    mkfs.ext4 -q -F -L casper-rw "$WORK/$IMAGE.dat"
done
attach() {
    LOOP=$(losetup --find --show "$WORK/$1.dat")
    dmsetup create vtoy_persistent --table "0 $(blockdev --getsz "$LOOP") linear $LOOP 0"
    MAPPED=true
    : >"$WORK/ventoy/ventoy_persistent_map"
    persistent_changes "$WORK/iso/minios" "$WORK/upper"
    init_union "$WORK/upper" "$WORK/union" "$WORK/bundles"
    perch_state_commit "$WORK/union"
    grep -qx 'boot_level=ok' "$WORK/state/boot-state"
    grep -qx 'mode=ventoy' "$WORK/state/boot-state"
    [ ! -e "$WORK/backend/minios" ]
    [ ! -e "$WORK/backend/session.conf" ]
    [ ! -e "$WORK/perch-root" ]
}
detach() {
    umount "$WORK/union"
    umount "$WORK/upper"
    umount "$WORK/backend"
    dmsetup remove vtoy_persistent
    MAPPED=false
    losetup -d "$LOOP"
    LOOP=""
    rm -f "$WORK/state/store-type"
}
attach A
printf 'store-A\n' >"$WORK/union/saved"
chmod 640 "$WORK/union/saved"
rm "$WORK/union/deleted"
detach
attach B
[ ! -e "$WORK/union/saved" ]
[ -f "$WORK/union/deleted" ]
printf 'store-B\n' >"$WORK/union/other"
detach
attach A
grep -qx store-A "$WORK/union/saved"
[ "$(stat -c %a "$WORK/union/saved")" = 640 ]
[ ! -e "$WORK/union/deleted" ]
[ ! -e "$WORK/union/other" ]
detach
rm "$WORK/ventoy/ventoy_persistent_map"
printf 'union=overlayfs\n' >"$WORK/cmdline"
persistent_changes "$WORK/iso/minios" "$WORK/upper" || true
init_union "$WORK/upper" "$WORK/union" "$WORK/bundles"
[ ! -e "$WORK/union/saved" ]
[ ! -e "$WORK/state/store-type" ]
umount "$WORK/union"
printf 'PASS: direct ext4 persistence, A/B/A isolation, whiteouts, permissions, no-backend RAM boot\n'
