#!/bin/bash
# Run with root in a private mount namespace.
set -euo pipefail

[ "$(id -u)" = 0 ] || exit 77
mount --make-rprivate /
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d /tmp/minios-external-bundles.XXXXXX)
cleanup() {
    umount -R "$WORK" 2>/dev/null || :
    rm -rf "$WORK"
}
trap cleanup EXIT
mount -t tmpfs tmpfs "$WORK"
mkdir -p "$WORK/source/modules" "$WORK/data" "$WORK/perch/minios/modules" "$WORK/bundles"
printf 'old\n' >"$WORK/source/00-core.sb"
printf 'new\n' >"$WORK/perch/minios/00-core.sb"
printf 'extra\n' >"$WORK/perch/minios/modules/app.sb"
mount --bind "$WORK/source" "$WORK/data"
mount -o remount,bind,ro "$WORK/data"

export MINIOS_CMDLINE_FILE="$WORK/cmdline"
export MINIOS_PERCH_ROOT="$WORK/perch"
export MINIOS_PERCH_ROOT_FILE="$WORK/perch_root"
export MINIOS_PERCH_STORE_FILE="$WORK/perch_store"
printf '' >"$MINIOS_CMDLINE_FILE"
printf '%s\n' "$MINIOS_PERCH_ROOT" >"$MINIOS_PERCH_ROOT_FILE"
LIVEKITNAME=minios
BEXT=sb
set +u
. "$ROOT/livekit-mos/lib/livekitlib"
debug_log() { :; }
bind_perch_bundles "$WORK/data"
[ "$(cat "$WORK/data/00-core.sb")" = new ]
[ "$(cat "$WORK/source/00-core.sb")" = old ]
[ "$WORK/data/00-core.sb" -ef "$WORK/perch/minios/00-core.sb" ]
[ "$(find_bundles "$WORK/data" "$WORK/perch/minios")" = $'00-core.sb\nmodules/app.sb' ]
printf 'PASS: external file replaces read-only source through a bind mount\n'
