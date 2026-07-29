#!/usr/bin/env bash
# Run from any directory: linux-live/initramfs/tests/run.sh [--strict]
set -u

ROOT=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
STRICT=0
[ "${1:-}" != --strict ] || STRICT=1
failed=0
skipped=0

run() {
    local label=$1 status
    shift
    printf '== %s ==\n' "$label"
    set +e
    output=$("$@" 2>&1)
    status=$?
    set -e
    printf '%s\n' "$output"
    if [[ $output == *'SKIP:'* || $output == *'# skip '* ]]; then skipped=$((skipped + 1)); fi
    [ "$status" -eq 0 ] || failed=1
}

set -e
if command -v bats >/dev/null 2>&1; then
    run bats bats "$ROOT"/*.bats
else
    printf 'SKIP: bats-core is unavailable\n'
    skipped=$((skipped + 1))
fi

if command -v shellcheck >/dev/null 2>&1; then
    printf '== shellcheck ==\n'
    if ! shellcheck "$ROOT/run.sh"; then
        failed=1
    fi
else
    printf 'SKIP: shellcheck is unavailable\n'
    skipped=$((skipped + 1))
fi

if [ "$STRICT" -eq 1 ] && [ "$skipped" -ne 0 ]; then
    printf 'FAIL: %s optional test layer(s) skipped in strict mode\n' "$skipped" >&2
    failed=1
fi
exit "$failed"
