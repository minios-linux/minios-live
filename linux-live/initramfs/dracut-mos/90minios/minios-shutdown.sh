#!/bin/sh
# Shutdown script for initramfs. It's automatically started by
# dracut's shutdown hook when system is powering off/rebooting.
# Purpose of this script is to unmount everything cleanly.
#
# Author: Tomas M <http://www.linux-live.org/>
# Author: crims0n <crims0n@minios.dev>

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Detect shutdown type from kernel command line or environment
SHUTDOWN_TYPE="shutdown"
if grep -q "reboot" /proc/cmdline 2>/dev/null || [ "$1" = "reboot" ]; then
    SHUTDOWN_TYPE="reboot"
elif cat /proc/1/cmdline 2>/dev/null | grep -q "reboot"; then
    SHUTDOWN_TYPE="reboot"
fi

# Resolve the active persistence session from the boot-time runtime authority.
# boot-state survives switch_root explicitly; minios-session-state is only a
# compatibility fallback because not every shutdown-initramfs keeps that file.
shutdown_dynblk_device_valid() {
    local INDEX
    case "$1" in /dev/dynblk*) ;; *) return 1 ;; esac
    INDEX=${1#/dev/dynblk}
    case "$INDEX" in '' | *[!0-9]*) return 1 ;; esac
    [ "$INDEX" -le 255 ]
}

resolve_shutdown_persistence() {
    local BOOT_STATE CANDIDATE STATE STATE_CONF STATE_SESSION LEVEL
    SHUTDOWN_SESSION=""
    SHUTDOWN_CONF=""
    SHUTDOWN_MODE=""
    SHUTDOWN_DYNBLK_DEVICE=""

    for BOOT_STATE in \
        /minios-persistence/boot-state \
        /run/initramfs/minios-persistence/boot-state \
        /oldroot/run/initramfs/minios-persistence/boot-state \
        /oldsys/run/initramfs/minios-persistence/boot-state; do
        [ -f "$BOOT_STATE" ] && break
    done
    if [ -f "$BOOT_STATE" ]; then
        LEVEL=$(sed -n 's/^boot_level=//p' "$BOOT_STATE" | tail -n 1)
        [ "$LEVEL" = ok ] || return 1
        SHUTDOWN_SESSION=$(sed -n 's/^session=//p' "$BOOT_STATE" | tail -n 1)
        SHUTDOWN_MODE=$(sed -n 's/^mode=//p' "$BOOT_STATE" | tail -n 1)
        SHUTDOWN_DYNBLK_DEVICE=$(sed -n 's/^dynblk_device=//p' "$BOOT_STATE" | tail -n 1)
    else
        for STATE in /minios-session-state /run/initramfs/minios-session-state \
                     /oldroot/run/initramfs/minios-session-state; do
            [ -f "$STATE" ] && break
        done
        [ -f "$STATE" ] || return 1
        SHUTDOWN_SESSION=$(sed -n 's/^SESSION=//p' "$STATE" | tail -n 1)
    fi
    case "$SHUTDOWN_SESSION" in '' | *[!0-9]*) return 1 ;; esac

    for STATE in /minios-session-state /run/initramfs/minios-session-state \
                 /oldroot/run/initramfs/minios-session-state; do
        [ -f "$STATE" ] || continue
        STATE_SESSION=$(sed -n 's/^SESSION=//p' "$STATE" | tail -n 1)
        [ "$STATE_SESSION" = "$SHUTDOWN_SESSION" ] || continue
        STATE_CONF=$(sed -n 's/^CONF=//p' "$STATE" | tail -n 1)
        for CANDIDATE in "$STATE_CONF" "/run/initramfs$STATE_CONF" \
                         "/oldroot/run/initramfs$STATE_CONF"; do
            [ -f "$CANDIDATE" ] || continue
            SHUTDOWN_CONF="$CANDIDATE"
            break 2
        done
    done
    if [ -z "$SHUTDOWN_CONF" ]; then
        for CANDIDATE in \
            /memory/data/minios/changes/session.conf \
            /run/initramfs/memory/data/minios/changes/session.conf \
            /oldroot/run/initramfs/memory/data/minios/changes/session.conf \
            /oldsys/run/initramfs/memory/data/minios/changes/session.conf; do
            [ -f "$CANDIDATE" ] || continue
            SHUTDOWN_CONF="$CANDIDATE"
            break
        done
    fi
    [ -n "$SHUTDOWN_CONF" ] || return 1
    [ -n "$SHUTDOWN_MODE" ] || SHUTDOWN_MODE=$(sed -n \
        "s/^session_mode\[$SHUTDOWN_SESSION\]=//p" "$SHUTDOWN_CONF" | tail -n 1)
    return 0
}

# Verify that the normal-root shutdown service saved a shutdown-policy
# SquashFS session before filesystem teardown.
verify_shutdown_squashfs_save() {
    local POLICY MARKER SAVED_SESSION

    resolve_shutdown_persistence || return 0
    [ "$SHUTDOWN_MODE" = squashfs ] || return 0
    POLICY=$(sed -n "s/^session_policy\[$SHUTDOWN_SESSION\]=//p" "$SHUTDOWN_CONF" | tail -n 1)
    [ -n "$POLICY" ] || POLICY=manual
    [ "$POLICY" = shutdown ] || return 0

    SHUTDOWN_SAVE_MARKER=""
    for MARKER in \
        /minios-persistence/shutdown-save-complete \
        /run/initramfs/minios-persistence/shutdown-save-complete \
        /oldroot/run/initramfs/minios-persistence/shutdown-save-complete \
        /oldsys/run/initramfs/minios-persistence/shutdown-save-complete \
        /sysroot/run/initramfs/minios-persistence/shutdown-save-complete; do
        [ -f "$MARKER" ] || continue
        SHUTDOWN_SAVE_MARKER="$MARKER"
        break
    done
    if [ -n "$SHUTDOWN_SAVE_MARKER" ]; then
        SAVED_SESSION=$(sed -n 's/^session=//p' "$SHUTDOWN_SAVE_MARKER" | tail -n 1)
        if [ "$SAVED_SESSION" = "$SHUTDOWN_SESSION" ]; then
            SQUASHFS_METADATA_FINALIZED=1
            return 0
        fi
    fi

    echo -e "${WHITE}[${RED}!${WHITE}]${RESET} SquashFS session #$SHUTDOWN_SESSION was not saved before filesystem teardown." >/dev/console
    return 1
}

detach_dynblk_device() {
    local DEVICE ATTEMPT
    DEVICE="$1"
    shutdown_dynblk_device_valid "$DEVICE" || return 1
    command -v dynblk >/dev/null 2>&1 || return 1
    ATTEMPT=1
    while [ "$ATTEMPT" -le 3 ]; do
        if dynblk unload "$DEVICE" --execute >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        ATTEMPT=$((ATTEMPT + 1))
    done
    return 1
}

detach_shutdown_dynblk() {
    resolve_shutdown_persistence || return 0
    [ "$SHUTDOWN_MODE" = dynblk ] || return 0
    [ -d /sys/module/dynblk ] || return 0
    command -v dynblk >/dev/null 2>&1 || {
        echo -e "${WHITE}[${RED}!${WHITE}]${RESET} The dynblk persistence backend is active but its control tool is unavailable." >/dev/console
        return 1
    }
    shutdown_dynblk_device_valid "$SHUTDOWN_DYNBLK_DEVICE" || {
        echo -e "${WHITE}[${RED}!${WHITE}]${RESET} The active dynblk device is missing from the boot persistence state." >/dev/console
        return 1
    }
    if detach_dynblk_device "$SHUTDOWN_DYNBLK_DEVICE"; then
        return 0
    fi
    echo -e "${WHITE}[${RED}!${WHITE}]${RESET} Could not detach dynblk persistence before unmounting its backing store." >/dev/console
    return 1
}

drain_remaining_dynblk() {
    local SYS DEVICE FAILED FOUND
    [ -d /sys/module/dynblk ] || return 0
    FAILED=0
    FOUND=0
    for SYS in /sys/block/dynblk[0-9]*; do
        [ -e "$SYS" ] || continue
        DEVICE="/dev/${SYS##*/}"
        shutdown_dynblk_device_valid "$DEVICE" || continue
        FOUND=1
        if ! detach_dynblk_device "$DEVICE"; then
            echo -e "${WHITE}[${RED}!${WHITE}]${RESET} Could not detach remaining dynblk device $DEVICE." >/dev/console
            FAILED=1
        fi
    done
    [ "$FOUND" -eq 0 ] || [ "$FAILED" -eq 0 ]
}

detach_free_loops() {
    losetup -a | cut -d : -f 1 | while read LOOP; do
        losetup -d "$LOOP" 2>/dev/null
    done
}

close_owned_crypt() {
    local MAPPER STATUS=0 STATE=/run/initramfs/minios-crypt
    [ -d "$STATE" ] || return 0
    [ -f "$STATE/mapper" ] && MAPPER=$(cat "$STATE/mapper")
    if [ -n "$MAPPER" ] && [ -b "/dev/mapper/$MAPPER" ] && ! cryptsetup close "$MAPPER" 2>/dev/null; then
        STATUS=1
    fi
    [ "$STATUS" -ne 0 ] || rm -rf "$STATE"
    return "$STATUS"
}

mark_persistence_session_clean() {
    local STATE CONF SESSION TMP JSON JSON_TMP

    if resolve_shutdown_persistence; then
        CONF="$SHUTDOWN_CONF"
        SESSION="$SHUTDOWN_SESSION"
    else
        for STATE in /minios-session-state /run/initramfs/minios-session-state; do
            [ -f "$STATE" ] && break
        done
        [ -f "$STATE" ] || return 0
        CONF=$(sed -n 's/^CONF=//p' "$STATE")
        SESSION=$(sed -n 's/^SESSION=//p' "$STATE")
        if [ ! -f "$CONF" ] && [ -f "/run/initramfs$CONF" ]; then
            CONF="/run/initramfs$CONF"
        fi
    fi
    [ -n "$CONF" ] && [ -n "$SESSION" ] && [ -f "$CONF" ] || return 1
    grep -qE '/(run/initramfs/)?memory/changes ' /proc/mounts 2>/dev/null && return 1

    TMP="${CONF}.tmp.$$"
    awk -v id="$SESSION" '
        /^running=/ { next }
        index($0, "session_state[" id "]=") == 1 { next }
        { print }
    ' "$CONF" >"$TMP" || return 1
    echo "session_state[$SESSION]=clean" >>"$TMP" || return 1

    JSON="$(dirname "$CONF")/session.json"
    JSON_TMP="${JSON}.tmp.$$"
    if command -v jq >/dev/null 2>&1 && [ -f "$JSON" ]; then
        jq --arg id "$SESSION" \
            'del(.running) | .sessions[$id].state = "clean"' \
            "$JSON" >"$JSON_TMP" || { rm -f "$TMP" "$JSON_TMP"; return 1; }
        sync
    fi
    rm -f "$JSON" || { rm -f "$TMP" "$JSON_TMP"; return 1; }
    sync
    mv -f "$TMP" "$CONF" || { rm -f "$TMP" "$JSON_TMP"; return 1; }
    if [ -f "$JSON_TMP" ]; then
        mv -f "$JSON_TMP" "$JSON" || return 1
    fi
    [ -z "$STATE" ] || rm -f "$STATE"
    sync
}

# $1=dir
umount_all() {
    tac /proc/mounts | cut -d " " -f 2 | grep "^$1" | while read LINE; do
        umount "$LINE" 2>/dev/null
        detach_free_loops
    done
}

SQUASHFS_SAVE_FAILED=0
SQUASHFS_METADATA_FINALIZED=0
DYNBLK_DETACH_FAILED=0
DYNBLK_DRAIN_FAILED=0
verify_shutdown_squashfs_save || SQUASHFS_SAVE_FAILED=1

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Detaching loop devices..."
if command -v mdev >/dev/null 2>&1; then
    mdev -s 2>/dev/null || true
fi
detach_free_loops

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Unmounting union filesystem..."
umount_all /oldroot

# Remember from which device we are started, so we can eject it later
DEVICE="$(cat /proc/mounts | grep -E '/(memory|initramfs/memory)/data' | grep /dev/ | head -n1 | cut -d " " -f 1)"

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Relocating blocking mounts..."
NR=100
tac /proc/mounts | cut -d " " -f 2 | grep "^/oldroot/" | while read LINE; do
    NR=$((NR + 1))
    mkdir -p /move/$NR
    mount --move "$LINE" /move/$NR 2>/dev/null
    umount /oldroot 2>/dev/null
done

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Clearing remaining mounts..."
for i in 1 2 3 4; do
    for d in $(ls -1 /move 2>/dev/null | sort); do
        umount_all /move/$d
    done
done

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Unmounting memory filesystem..."
umount_all /oldroot/run/initramfs/memory/changes
umount_all /oldsys/run/initramfs/memory/changes
umount_all /run/initramfs/memory/changes
umount_all /memory/changes
if resolve_shutdown_persistence && [ "$SHUTDOWN_MODE" = dynblk ] && [ -d /sys/module/dynblk ]; then
    echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Detaching dynblk persistence..."
fi
detach_shutdown_dynblk || DYNBLK_DETACH_FAILED=1
if [ -d /sys/module/dynblk ]; then
    echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Draining remaining dynblk devices..."
fi
drain_remaining_dynblk || DYNBLK_DRAIN_FAILED=1
if [ "$SQUASHFS_SAVE_FAILED" -eq 0 ] && [ "$DYNBLK_DETACH_FAILED" -eq 0 ] && \
        [ "$DYNBLK_DRAIN_FAILED" -eq 0 ] && [ "$SQUASHFS_METADATA_FINALIZED" -eq 0 ]; then
    mark_persistence_session_clean || true
fi
umount_all /oldroot/run/initramfs/memory
umount_all /oldsys/run/initramfs/memory
umount_all /run/initramfs/memory
umount_all /memory
close_owned_crypt

# Eject CD/DVD if booted from optical media
for i in $(cat /proc/sys/dev/cdrom/info 2>/dev/null | grep "^drive name:" | awk '{print $3}'); do
    if [ "$DEVICE" = "/dev/$i" ]; then
        echo -e "${WHITE}[${YELLOW}!${WHITE}]${RESET} Ejecting optical drive ${CYAN}/dev/$i${RESET}..."
        eject -r /dev/$i 2>/dev/null || eject /dev/$i 2>/dev/null || true
        echo -e "${WHITE}[${YELLOW}!${WHITE}]${RESET} CD/DVD tray will close in 6 seconds..."
        sleep 6
        eject -t /dev/$i 2>/dev/null || true
    fi
done

if [ "$SHUTDOWN_TYPE" = "reboot" ]; then
    echo -e "${WHITE}[${GREEN}OK${WHITE}]${RESET} System prepared for reboot"
else
    echo -e "${WHITE}[${GREEN}OK${WHITE}]${RESET} System prepared for shutdown"
fi
