#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    FIXTURE=""
    IMAGE="${MINIOS_INITRD_IMAGE:-}"
    EXPECT_CRYPT="${MINIOS_EXPECT_CRYPT:-0}"
}

teardown() {
    [ -z "$FIXTURE" ] || rm -rf "$FIXTURE"
}

list_image() {
    # The built-in fixture is deliberately a plain newc archive, so inspect it
    # with cpio even on hosts that also provide lsinitramfs for compressed initrds.
    if [ -n "$FIXTURE" ] && command -v cpio >/dev/null 2>&1; then
        cpio -it <"$IMAGE" 2>/dev/null
    elif command -v lsinitramfs >/dev/null 2>&1; then
        lsinitramfs "$IMAGE"
    elif command -v lsinitrd >/dev/null 2>&1; then
        lsinitrd "$IMAGE"
    elif command -v cpio >/dev/null 2>&1; then
        cpio -it <"$IMAGE" 2>/dev/null
    else
        return 127
    fi
}

@test "generated initrd contains the required runtime payload" {
    if [ -z "$IMAGE" ]; then
        command -v cpio >/dev/null 2>&1 || skip "set MINIOS_INITRD_IMAGE or install cpio for the fixture"
        FIXTURE=$(mktemp -d)
        mkdir -p "$FIXTURE/tree/bin" "$FIXTURE/tree/etc" "$FIXTURE/tree/lib/modules"
        : >"$FIXTURE/tree/init"
        : >"$FIXTURE/tree/lib/livekitlib"
        : >"$FIXTURE/tree/bin/cryptsetup"
        : >"$FIXTURE/tree/bin/e2fsck"
        : >"$FIXTURE/tree/bin/resize2fs"
        : >"$FIXTURE/tree/etc/minios-initramfs-crypt"
        : >"$FIXTURE/tree/lib/modules/dm-crypt.ko"
        printf '%s\n' init lib/livekitlib bin/cryptsetup bin/e2fsck bin/resize2fs etc/minios-initramfs-crypt lib/modules/dm-crypt.ko |
            cpio -o -H newc -D "$FIXTURE/tree" >"$FIXTURE/initrd.cpio" 2>/dev/null
        IMAGE="$FIXTURE/initrd.cpio"
        EXPECT_CRYPT=1
    fi

    [ -r "$IMAGE" ]
    command -v lsinitramfs >/dev/null 2>&1 ||
        command -v lsinitrd >/dev/null 2>&1 ||
        command -v cpio >/dev/null 2>&1 ||
        skip "lsinitramfs, lsinitrd, or cpio is required"

    run list_image
    [ "$status" -eq 0 ]
    CONTENTS="$output"
    grep -Eq '(^|[[:space:]/])lib/livekitlib$' <<<"$CONTENTS"
    grep -Eq '(^|[[:space:]/])(init|minios-init)$' <<<"$CONTENTS"
    grep -Eq '(^|[[:space:]/])([^/[:space:]]+/)*e2fsck$' <<<"$CONTENTS"
    grep -Eq '(^|[[:space:]/])([^/[:space:]]+/)*resize2fs$' <<<"$CONTENTS"
    if [ "$EXPECT_CRYPT" = 1 ]; then
        grep -Eq '(^|[[:space:]/])etc/minios-initramfs-crypt$' <<<"$CONTENTS"
        grep -Eq '(^|[[:space:]/])([^/[:space:]]+/)*cryptsetup$' <<<"$CONTENTS"
        grep -Eq 'dm-crypt' <<<"$CONTENTS"
    fi
}
