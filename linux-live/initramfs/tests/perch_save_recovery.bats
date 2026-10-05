setup() {
    WORK=$(mktemp -d)
    STORE="$WORK/changes"
    TXN="$STORE/.ram-save-fixture"
    mkdir -p "$TXN/new" "$STORE/1" "$STORE/2"
    printf old >"$STORE/1/changes.img"
    printf other >"$STORE/2/changes.img"
    printf new >"$TXN/new/changes.img"
    printf '.ram-save-fixture\n' >"$TXN/new/.ram-save-owner"
    printf '1\n' >"$TXN/session"
    printf '1\n' >"$TXN/had-session"
    printf old-metadata >"$TXN/session.conf.before"
    : >"$TXN/session.json.absent"
    : >"$TXN/ready"
    . "$BATS_TEST_DIRNAME/../livekit-mos/lib/livekitlib"
    sync() { :; }
    boot_warning_notify() { :; }
}

teardown() {
    rm -rf "$WORK"
}

@test "boot restores a session interrupted between directory renames" {
    mv "$STORE/1" "$TXN/old"
    recover_perch_save "$STORE"
    [ "$(cat "$STORE/1/changes.img")" = old ]
    [ "$(cat "$STORE/session.conf")" = old-metadata ]
    [ "$(cat "$STORE/2/changes.img")" = other ]
    [ ! -e "$TXN" ]
}

@test "boot restores metadata after an uncommitted replacement" {
    mv "$STORE/1" "$TXN/old"
    mv "$TXN/new" "$STORE/1"
    printf partial >"$STORE/session.conf"
    printf '{}' >"$STORE/session.json"
    recover_perch_save "$STORE"
    [ "$(cat "$STORE/1/changes.img")" = old ]
    [ "$(cat "$STORE/session.conf")" = old-metadata ]
    [ ! -e "$STORE/session.json" ]
}

@test "boot preserves a committed replacement" {
    mv "$STORE/1" "$TXN/old"
    mv "$TXN/new" "$STORE/1"
    printf new-metadata >"$STORE/session.conf"
    : >"$TXN/committed"
    recover_perch_save "$STORE"
    [ "$(cat "$STORE/1/changes.img")" = new ]
    [ "$(cat "$STORE/session.conf")" = new-metadata ]
    [ ! -e "$TXN" ]
}

@test "boot refuses an unrecognized target instead of deleting it" {
    mv "$STORE/1" "$TXN/old"
    mkdir "$STORE/1"
    printf unrelated >"$STORE/1/changes.img"
    run recover_perch_save "$STORE"
    [ "$status" -ne 0 ]
    [ "$(cat "$STORE/1/changes.img")" = unrelated ]
    [ "$(cat "$TXN/old/changes.img")" = old ]
}
