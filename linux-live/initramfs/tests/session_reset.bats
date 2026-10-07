#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    export LIB="$ROOT/livekit-mos/lib/livekitlib"
    export BB="$ROOT/livekit-mos/bin/busybox"
    WORK=$(mktemp -d)
    export SESSION="$WORK/session" MINIOS_RESET_BUNDLES="$WORK/bundles"
    export MINIOS_PROC_MOUNTS="$WORK/mounts"
    mkdir -p "$SESSION" "$WORK/bin" "$MINIOS_RESET_BUNDLES"
    : >"$MINIOS_PROC_MOUNTS"
    # Use the actual initrd applets, not richer host cp/stat implementations.
    for app in awk cat chmod chown cp grep ls mkdir mv readlink rm rmdir touch; do
        ln -s "$BB" "$WORK/bin/$app"
    done
    export PATH="$WORK/bin:$PATH"
}

teardown() {
    /bin/rm -rf "$WORK"
}

fixture() {
    local base=$1
    mkdir -p "$base"/{etc,usr/bin,usr/share/demo,home/live/.config,home/live/.local/bin,srv,root,var/lib/dpkg/info,var/lib/demo,var/lib/live/config}
    printf 'live:x:1000:1000::/home/live:/bin/bash\n' >"$base/etc/passwd"
    printf 'live:password\n' >"$base/etc/shadow"
    printf 'setting\n' >"$base/etc/custom.conf"
    printf 'setting\n' >"$base/home/live/.config/demo.conf"
    printf 'setting\n' >"$base/root/.bashrc"
    printf 'document\n' >"$base/home/live/report with spaces.txt"
    printf 'script\n' >"$base/home/live/my-script.sh"
    chmod 700 "$base/home/live/my-script.sh"
    printf 'database\n' >"$base/var/lib/demo/database"
    printf 'service data\n' >"$base/srv/data"
    printf 'program\n' >"$base/usr/bin/demo"
    printf 'program\n' >"$base/home/live/.local/bin/demo"
    printf 'package asset\n' >"$base/usr/share/demo/program.asset"
    printf 'personal data\n' >"$base/usr/share/demo/personal.data"
    printf '/usr/bin/demo\n/usr/share/demo\n/usr/share/demo/program.asset\n/etc/custom.conf\n' >"$base/var/lib/dpkg/info/demo.list"
    touch "$base/var/lib/live/config/"{user-setup,root-setup,xfce4-panel,network,debconf}
    touch "$base/home/live/.wh.old-document"
    chmod 750 "$base/home/live"
}

@test "settings reset keeps configuration and arbitrary data but removes package software" {
    fixture "$SESSION"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" settings aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/etc/custom.conf" ]
    [ -f "$SESSION/home/live/.config/demo.conf" ]
    [ -f "$SESSION/srv/data" ]
    [ -f "$SESSION/var/lib/demo/database" ]
    [ -f "$SESSION/usr/share/demo/personal.data" ]
    [ ! -e "$SESSION/usr/share/demo/program.asset" ]
    [ ! -e "$SESSION/usr/bin" ]
    [ ! -e "$SESSION/var/lib/dpkg" ]
    [ -f "$SESSION/home/live/.local/bin/demo" ]
    [ ! -e "$SESSION/home/live/.wh.old-document" ]
    [ -f "$SESSION/var/lib/live/config/xfce4-panel" ]
    [ ! -e "$SESSION/var/lib/live/config/debconf" ]
    [ ! -e "$SESSION/.minios-session-reset" ]
    [ "$(/usr/bin/stat -c %a "$SESSION/home/live")" = 750 ]
    [ "$(/usr/bin/stat -c %a "$SESSION/home/live/my-script.sh")" = 700 ]
}

@test "data reset preserves both home trees and their live-config markers but reruns system setup" {
    fixture "$SESSION"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/etc/passwd" ]
    [ -f "$SESSION/etc/shadow" ]
    [ ! -e "$SESSION/etc/custom.conf" ]
    [ -f "$SESSION/home/live/.config/demo.conf" ]
    [ -f "$SESSION/root/.bashrc" ]
    [ -f "$SESSION/home/live/report with spaces.txt" ]
    [ -f "$SESSION/home/live/my-script.sh" ]
    [ -f "$SESSION/var/lib/demo/database" ]
    [ -f "$SESSION/var/lib/live/config/user-setup" ]
    [ -f "$SESSION/var/lib/live/config/root-setup" ]
    [ -f "$SESSION/var/lib/live/config/xfce4-panel" ]
    [ ! -e "$SESSION/var/lib/live/config/network" ]
}

@test "reset rebuilds AUFS as OverlayFS and rollback restores the exact original layout" {
    fixture "$SESSION"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data overlayfs'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/changes/srv/data" ]
    [ -d "$SESSION/workdir" ]
    run "$BB" sh -c '. "$LIB"; session_reset_recover "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/usr/bin/demo" ]
    [ -f "$SESSION/etc/custom.conf" ]
    [ ! -e "$SESSION/changes" ]
    [ ! -e "$SESSION/workdir" ]
}

@test "reset rebuilds an OverlayFS upper as AUFS without carrying workdir" {
    mkdir "$SESSION/changes" "$SESSION/workdir"
    fixture "$SESSION/changes"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" settings aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/srv/data" ]
    [ ! -e "$SESSION/changes" ]
    [ ! -e "$SESSION/workdir" ]
}

@test "copy failure leaves original settings and programs untouched" {
    fixture "$SESSION"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; cp() { return 1; }; session_reset_prepare "$SESSION" data aufs'
    [ "$status" -ne 0 ]
    [ -f "$SESSION/usr/bin/demo" ]
    [ -f "$SESSION/etc/custom.conf" ]
    [ ! -e "$SESSION/.minios-session-reset" ]
}

@test "package files from current base modules are reset even without copied-up dpkg lists" {
    fixture "$SESSION"
    mkdir -p "$MINIOS_RESET_BUNDLES/00-core/var/lib/dpkg/info"
    mv "$SESSION/var/lib/dpkg/info/demo.list" "$MINIOS_RESET_BUNDLES/00-core/var/lib/dpkg/info/"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" settings aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ ! -e "$SESSION/usr/share/demo/program.asset" ]
    [ -f "$SESSION/usr/share/demo/personal.data" ]
}

@test "symlinks are copied without modifying or traversing their targets" {
    mkdir "$WORK/outside"
    printf 'outside\n' >"$WORK/outside/file"
    ln -s "$WORK/outside" "$SESSION/external"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" settings aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ -L "$SESSION/external" ]
    [ "$(cat "$WORK/outside/file")" = outside ]
}

@test "nested mounts and forged transaction symlinks reject reset" {
    fixture "$SESSION"
    printf '/dev/other %s/srv ext4 rw 0 0\n' "$SESSION" >"$MINIOS_PROC_MOUNTS"
    run "$BB" sh -c '. "$LIB"; session_reset_prepare "$SESSION" data aufs'
    [ "$status" -ne 0 ]
    [ -f "$SESSION/usr/bin/demo" ]
    : >"$MINIOS_PROC_MOUNTS"
    ln -s "$WORK" "$SESSION/.minios-session-reset"
    run "$BB" sh -c '. "$LIB"; session_reset_prepare "$SESSION" data aufs'
    [ "$status" -ne 0 ]
    [ -f "$SESSION/usr/bin/demo" ]
}

@test "interrupted reset rolls back metadata and stops activation for fresh session selection" {
    fixture "$SESSION"
    export CONF="$WORK/session.conf"
    printf 'session_version[1]=old\n' >"$CONF"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data aufs "$CONF"'
    [ "$status" -eq 0 ]
    printf 'session_version[1]=new\n' >"$CONF"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_recover "$SESSION" "$CONF"'
    [ "$status" -ne 0 ]
    [ "$(cat "$CONF")" = 'session_version[1]=old' ]
    [ -f "$SESSION/usr/bin/demo" ]
    [ ! -e "$SESSION/.minios-session-reset" ]
}

@test "package conffiles outside etc are retained only in settings mode" {
    fixture "$SESSION"
    printf '/usr/share/demo/program.asset\n' >"$SESSION/var/lib/dpkg/info/demo.conffiles"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" settings aufs'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/usr/share/demo/program.asset" ]
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_recover "$SESSION"; session_reset_prepare "$SESSION" data aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ ! -e "$SESSION/usr/share/demo/program.asset" ]
}

@test "incompatible-session menu carries both reset modes and retains the unchanged choice" {
    mkdir "$SESSION/1"
    printf 'default=1\nsession_mode[1]=native\nsession_version[1]=old\nsession_edition[1]=old\nsession_union[1]=aufs\n' >"$SESSION/session.conf"
    export MINIOS_MENU_TTY=/dev/null
    export OPTIONS="$WORK/options"
    for choice in 'Reset, keep settings' 'Reset, keep data' 'Yes, proceed at my own risk'; do
        export CHOICE="$choice"
        run bash -c '
            . "$LIB"
            get_union_fs() { echo overlayfs; }
            date_diff_since_now() { echo 0; }
            PERCHSIZE=0
            ncurses-menu() {
                case "$2" in
                "Select session:") echo "#1 [Native]" >&2 ;;
                *) printf "%s\n" "$@" >"$OPTIONS"; echo "$CHOICE" >&2 ;;
                esac
            }
            restore_perch_session /dev/test "$SESSION" ask ask "" false
        '
        [ "$status" -eq 0 ]
        case "$choice" in
        'Reset, keep settings') [ "$output" = '1 native false none none settings' ] ;;
        'Reset, keep data') [ "$output" = '1 native false none none data' ] ;;
        *) [ "$output" = '1 native false none none' ] ;;
        esac
        grep -Fqx 'No, return to session list' "$OPTIONS"
        grep -Fqx 'Reset, keep settings' "$OPTIONS"
        grep -Fqx 'Reset, keep data' "$OPTIONS"
    done
}

@test "SquashFS reset intent is boot-scoped without changing snapshot compatibility" {
    export CONF="$WORK/session.conf" MINIOS_BOOT_ID_FILE="$WORK/boot-id"
    printf 'boot-test\n' >"$MINIOS_BOOT_ID_FILE"
    printf 'session_version[1]=old\nsession_edition[1]=old\nsession_union[1]=aufs\nsession_generation[1]=7\n' >"$CONF"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; config_value() { echo new; }; squashfs_reset_pending "$CONF" 1'
    [ "$status" -eq 0 ]
    grep -Fqx 'session_version[1]=old' "$CONF"
    grep -Fqx 'session_union[1]=aufs' "$CONF"
    grep -Fqx 'session_generation[1]=7' "$CONF"
    grep -Fqx 'session_reset_version[1]=new' "$CONF"
    grep -Fqx 'session_reset_boot_id[1]=boot-test' "$CONF"
}

@test "reset changes only the selected session, leaving common root, base modules and sibling sessions untouched" {
    fixture "$SESSION"
    fixture "$WORK/common-root"
    fixture "$WORK/sibling-session"
    fixture "$MINIOS_RESET_BUNDLES/00-core"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ ! -e "$SESSION/usr/bin/demo" ]
    [ ! -e "$SESSION/etc/custom.conf" ]
    for base in "$WORK/common-root" "$WORK/sibling-session" "$MINIOS_RESET_BUNDLES/00-core"; do
        [ "$(cat "$base/usr/bin/demo")" = program ]
        [ "$(cat "$base/etc/custom.conf")" = setting ]
        [ "$(cat "$base/var/lib/demo/database")" = database ]
        [ -f "$base/var/lib/live/config/xfce4-panel" ]
    done
}

@test "the common root cannot be selected as a reset target" {
    run "$BB" sh -c '. "$LIB"; session_reset_prepare / data aufs'
    [ "$status" -ne 0 ]
    run "$BB" sh -c '. "$LIB"; session_reset_prepare /tmp/.. data aufs'
    [ "$status" -ne 0 ]
}

@test "data reset retains browser databases, SSH identity, and private keys" {
    fixture "$SESSION"
    mkdir -p "$SESSION/home/live/.config/chromium/Default" "$SESSION/etc/ssh" "$SESSION/etc/ssl/private"
    printf 'bookmarks\n' >"$SESSION/home/live/.config/chromium/Default/Bookmarks"
    printf 'passwords\n' >"$SESSION/home/live/.config/chromium/Default/Login Data"
    printf 'preferences\n' >"$SESSION/home/live/.config/chromium/Default/Preferences"
    printf 'key\n' >"$SESSION/etc/ssh/ssh_host_ed25519_key"
    printf 'key\n' >"$SESSION/etc/ssl/private/service.key"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data aufs && session_reset_finish "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/home/live/.config/chromium/Default/Bookmarks" ]
    [ -f "$SESSION/home/live/.config/chromium/Default/Login Data" ]
    [ -f "$SESSION/home/live/.config/chromium/Default/Preferences" ]
    [ -f "$SESSION/etc/ssh/ssh_host_ed25519_key" ]
    [ -f "$SESSION/etc/ssl/private/service.key" ]
}

@test "failure while installing the candidate rolls back both data and layout" {
    fixture "$SESSION"
    run "$BB" sh -c '
        . "$LIB"
        sync() { :; }
        mv() {
            if [ "$3" = "$SESSION/" ]; then return 1; fi
            "$BB" mv "$@"
        }
        session_reset_prepare "$SESSION" data overlayfs
    '
    [ "$status" -ne 0 ]
    [ -f "$SESSION/usr/bin/demo" ]
    [ -f "$SESSION/etc/custom.conf" ]
    [ -f "$SESSION/home/live/report with spaces.txt" ]
    [ ! -e "$SESSION/changes" ]
    [ ! -e "$SESSION/.minios-session-reset" ]
}

@test "both modes retain every home and root file even when dpkg identifies it as software or configuration" {
    for mode in settings data; do
        mkdir -p "$SESSION/home/live/.config" "$SESSION/home/live/.cache" "$SESSION/home/live/.local/bin" "$SESSION/root/.config" "$SESSION/root/.cache" "$SESSION/root/.local/bin" "$SESSION/var/lib/dpkg/info"
        printf 'user settings\n' >"$SESSION/home/live/.config/settings.conf"
        printf 'user cache\n' >"$SESSION/home/live/.cache/data"
        printf 'user program\n' >"$SESSION/home/live/.local/bin/program"
        printf 'root settings\n' >"$SESSION/root/.config/settings.conf"
        printf 'root cache\n' >"$SESSION/root/.cache/data"
        printf 'root program\n' >"$SESSION/root/.local/bin/program"
        printf 'root shell\n' >"$SESSION/root/.bashrc"
        printf '/home/live/.local/bin/program\n/root/.local/bin/program\n' >"$SESSION/var/lib/dpkg/info/demo.list"
        printf '/home/live/.config/settings.conf\n/root/.config/settings.conf\n' >"$SESSION/var/lib/dpkg/info/demo.conffiles"
        mkdir "$WORK/expected-$mode"
        cp -a "$SESSION/home" "$SESSION/root" "$WORK/expected-$mode/"
        export RESET_MODE="$mode"
        run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" "$RESET_MODE" aufs && session_reset_finish "$SESSION"'
        [ "$status" -eq 0 ]
        diff -r "$WORK/expected-$mode/home" "$SESSION/home"
        diff -r "$WORK/expected-$mode/root" "$SESSION/root"
    done
}

@test "recovery can be interrupted and repeated without deleting already-restored data" {
    fixture "$SESSION"
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_prepare "$SESSION" data aufs'
    [ "$status" -eq 0 ]
    run "$BB" sh -c '
        . "$LIB"
        sync() { :; }
        mv() {
            "$BB" mv "$@" || return 1
            if [ "$3" = "$SESSION/etc" ]; then exit 77; fi
        }
        session_reset_recover "$SESSION"
    '
    [ "$status" -eq 77 ]
    [ -f "$SESSION/etc/custom.conf" ]
    run "$BB" sh -c '. "$LIB"; sync() { :; }; session_reset_recover "$SESSION"'
    [ "$status" -eq 0 ]
    [ -f "$SESSION/etc/custom.conf" ]
    [ -f "$SESSION/usr/bin/demo" ]
    [ -f "$SESSION/home/live/report with spaces.txt" ]
    [ ! -e "$SESSION/.minios-session-reset" ]
}
