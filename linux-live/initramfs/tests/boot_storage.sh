#!/bin/bash
# Exercise the early policy with private configuration and mocked mounts.
set -e
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
export MINIOS_BOOT_SOURCE_ONLY=true
export MINIOS_BOOT_CONFIG="$WORK/config.conf"
export MINIOS_BOOT_CONFIG_DIR="$WORK/config.conf.d"
export MINIOS_BOOT_CMDLINE_FILE="$WORK/cmdline"
export MINIOS_BOOT_STATE="$WORK/boot-state"
export MINIOS_BOOT_LOG_FILE="$WORK/minios-boot.log"
export MINIOS_JOURNAL_DROPIN="$WORK/journald.conf"
export MINIOS_VOLATILE_LOG_ROOT="$WORK/log"
export MINIOS_PERSISTENT_LOG_BIND="$WORK/log-store"
export MINIOS_APT_ARCHIVES="$WORK/archives"
export MINIOS_PROC_SWAPS="$WORK/swaps"
export MINIOS_PROC_MEMINFO="$WORK/meminfo"
export MINIOS_BROWSER_POLICY_FILE="$WORK/browser.policy"
mkdir -p "$MINIOS_BOOT_CONFIG_DIR" "$MINIOS_VOLATILE_LOG_ROOT"
printf 'LIVE_LOG_STORAGE="persistent"\nLIVE_APT_CACHE="persistent"\nLIVE_CONFIG_CMDLINE="browser-cache=volatile"\n' >"$MINIOS_BOOT_CONFIG"
printf 'LIVE_LOG_STORAGE="volatile"\n' >"$MINIOS_BOOT_CONFIG_DIR/10-policy.conf"
printf 'boot=live log-storage=persistent apt-cache=volatile\n' >"$MINIOS_BOOT_CMDLINE_FILE"
printf 'boot_level=ok\ndurable=1\n' >"$MINIOS_BOOT_STATE"
printf 'Filename Type Size Used Priority\n/dev/zram0 partition 1024 0 100\n' >"$MINIOS_PROC_SWAPS"
printf 'MemAvailable: 3145728 kB\n' >"$MINIOS_PROC_MEMINFO"
. "$ROOT/livekit-mos/bin/minios-boot"
mount() {
    printf '%s\n' "$*" >>"$WORK/mounts"
    if [ "${FAIL_LOG_BIND:-}" = true ] &&
       [ "$*" = "--bind $MINIOS_PERSISTENT_LOG_BIND/live $MINIOS_VOLATILE_LOG_ROOT/live" ]; then
        return 1
    fi
}
umount() { printf '%s\n' "$*" >>"$WORK/unmounts"; }
chown() { :; }
load_storage_policy
[ "$LIVE_LOG_STORAGE" = persistent ]
[ "$LIVE_APT_CACHE" = volatile ]
[ "$LIVE_BROWSER_CACHE" = volatile ]
prepare_browser_cache
[ "$(cat "$MINIOS_BROWSER_POLICY_FILE")" = volatile ]
set_log_storage
[ ! -e "$MINIOS_JOURNAL_DROPIN" ]
[ -z "$(set_apt_cache 2>&1)" ]
grep -Fq 'APT archives: volatile 512m' "$MINIOS_BOOT_LOG_FILE"
grep -Fq "tmpfs $MINIOS_APT_ARCHIVES" "$WORK/mounts"
[ -d "$MINIOS_APT_ARCHIVES/partial" ]

# Config-file and drop-in order, followed by kernel command-line precedence.
printf 'boot=live log-storage=volatile apt-cache=persistent browser-cache=persistent\n' >"$MINIOS_BOOT_CMDLINE_FILE"
CMDLINE=$(cat "$MINIOS_BOOT_CMDLINE_FILE")
load_storage_policy
[ "$LIVE_LOG_STORAGE" = volatile ]
[ "$LIVE_APT_CACHE" = persistent ]
[ "$LIVE_BROWSER_CACHE" = persistent ]
prepare_browser_cache
[ ! -e "$MINIOS_BROWSER_POLICY_FILE" ]
[ -z "$(set_log_storage 2>&1)" ]
grep -Fq 'Journald: bounded volatile storage' "$MINIOS_BOOT_LOG_FILE"
grep -Fq 'Text system logs: bounded volatile storage' "$MINIOS_BOOT_LOG_FILE"
grep -Fq -- "--bind $MINIOS_VOLATILE_LOG_ROOT $MINIOS_PERSISTENT_LOG_BIND" "$WORK/mounts"
grep -Fq "tmpfs $MINIOS_VOLATILE_LOG_ROOT" "$WORK/mounts"
grep -Fq -- "--bind $MINIOS_PERSISTENT_LOG_BIND/minios $MINIOS_VOLATILE_LOG_ROOT/minios" "$WORK/mounts"
grep -Fq -- "--bind $MINIOS_PERSISTENT_LOG_BIND/live $MINIOS_VOLATILE_LOG_ROOT/live" "$WORK/mounts"
FAIL_LOG_BIND=true
if set_log_storage; then
    echo 'Failed boot-log bind was accepted' >&2
    exit 1
fi
unset FAIL_LOG_BIND
grep -Fqx "$MINIOS_VOLATILE_LOG_ROOT/minios" "$WORK/unmounts"
grep -Fqx "$MINIOS_VOLATILE_LOG_ROOT" "$WORK/unmounts"
grep -Fqx "$MINIOS_PERSISTENT_LOG_BIND" "$WORK/unmounts"

printf 'Filename Type Size Used Priority\n/dev/sda2 partition 1024 0 100\n' >"$MINIOS_PROC_SWAPS"
LIVE_APT_CACHE=volatile
LIVE_BROWSER_CACHE=volatile
[ -z "$(set_apt_cache 2>&1)" ]
[ -z "$(prepare_browser_cache 2>&1)" ]
grep -Fq 'APT RAM cache skipped: non-zRAM swap is active' "$MINIOS_BOOT_LOG_FILE"
grep -Fq 'Browser RAM cache skipped: non-zRAM swap is active' "$MINIOS_BOOT_LOG_FILE"
[ ! -e "$MINIOS_BROWSER_POLICY_FILE" ]

# A requested policy must not apply if persistence was not durable.
printf 'boot_level=failed\ndurable=0\n' >"$MINIOS_BOOT_STATE"
load_storage_policy
[ "$LIVE_LOG_STORAGE" = persistent ]
[ "$LIVE_APT_CACHE" = persistent ]
[ "$LIVE_BROWSER_CACHE" = persistent ]
[ -z "$(MINIOS_BOOT_LOG_FILE="$WORK/missing/minios-boot.log" log_storage_status 'cache status' 2>&1)" ]
printf '%s\n' 'PASS: storage policy precedence, mounts, and failed-session fallback'
