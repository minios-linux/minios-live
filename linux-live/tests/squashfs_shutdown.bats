#!/usr/bin/env bats

setup() {
    ROOT="$BATS_TEST_DIRNAME/.."
    UNIT="$ROOT/scripts/00-core/rootcopy-install/usr/lib/systemd/system/minios-squashfs-shutdown-save.service"
    LINK="$ROOT/scripts/00-core/rootcopy-install/etc/systemd/system/multi-user.target.wants/minios-squashfs-shutdown-save.service"
    SYSV="$ROOT/scripts/00-core/rootcopy-install/etc/init.d/minios-squashfs-shutdown-save"
    DRACUT_SYSV="$ROOT/scripts/00-core/rootcopy-install/etc/init.d/minios-dracut-shutdown"
    HANDOFF="$ROOT/scripts/00-core/rootcopy-install/usr/sbin/minios-initramfs-shutdown"
    CORE_INSTALL="$ROOT/scripts/00-core/install"
}

@test "core keeps SquashFS shutdown save active across target isolates" {
    [ -f "$UNIT" ]
    grep -Fqx 'After=local-fs.target' "$UNIT"
    grep -Fqx 'Before=display-manager.service' "$UNIT"
    ! grep -Fq 'systemd-user-sessions.service' "$UNIT"
    grep -Fqx 'RefuseManualStart=yes' "$UNIT"
    grep -Fqx 'RefuseManualStop=yes' "$UNIT"
    grep -Fqx 'IgnoreOnIsolate=yes' "$UNIT"
    grep -Fqx 'ExecStart=/bin/true' "$UNIT"
    grep -Fqx 'ExecStop=/usr/bin/minios-squashfs-shutdown-save' "$UNIT"
    grep -Fqx 'RemainAfterExit=yes' "$UNIT"
    grep -Fqx 'WantedBy=multi-user.target' "$UNIT"
    [ -L "$LINK" ]
    [ "$(readlink "$LINK")" = '/usr/lib/systemd/system/minios-squashfs-shutdown-save.service' ]
    [ ! -e "$ROOT/scripts/00-core/rootcopy-install/etc/systemd/system/graphical.target.wants/minios-squashfs-shutdown-save.service" ]
    [ ! -e "$ROOT/scripts/00-core/rootcopy-install/etc/systemd/system/shutdown.target.wants/minios-squashfs-shutdown-save.service" ]
}


@test "core provides a Devuan SysV shutdown trigger around sendsigs" {
    [ -x "$SYSV" ]
    grep -Fqx '# Required-Stop:     sendsigs' "$SYSV"
    grep -Fqx '# X-Stop-After:      lightdm minios-xorg' "$SYSV"
    grep -Fqx '# Default-Start:' "$SYSV"
    grep -Fqx '# Default-Stop:      0 6' "$SYSV"
    grep -Fq 'minios-svc enable minios-squashfs-shutdown-save' "$CORE_INSTALL"
}

@test "Devuan trigger saves only for halt and reboot runlevels" {
    work=$(mktemp -d)
    called="$work/called"
    save="$work/save"
    cat >"$save" <<'EOF'
#!/bin/sh
printf '%s\n' "${MINIOS_SHUTDOWN_FORCE:-}" >"$MINIOS_TEST_CALLED"
EOF
    chmod 755 "$save"

    run env runlevel=2 MINIOS_TEST_CALLED="$called" MINIOS_SHUTDOWN_SAVE_COMMAND="$save" "$SYSV" stop
    [ "$status" -eq 0 ]
    [ ! -e "$called" ]

    run env runlevel=6 MINIOS_TEST_CALLED="$called" MINIOS_SHUTDOWN_SAVE_COMMAND="$save" "$SYSV" stop
    [ "$status" -eq 0 ]
    [ "$(cat "$called")" = 1 ]
    rm -rf "$work"
}

@test "Devuan dracut handoff is ordered before generic filesystem teardown" {
    [ -x "$DRACUT_SYSV" ]
    [ -x "$HANDOFF" ]
    run sh -n "$DRACUT_SYSV"
    [ "$status" -eq 0 ]
    grep -Fqx '# Should-Stop:       umountfs' "$DRACUT_SYSV"
    grep -Fqx '# X-Stop-After:      networking hwclock.sh rpcbind nfs-common umountnfs.sh sendsigs' "$DRACUT_SYSV"
    grep -Fqx '# Default-Stop:      0 6' "$DRACUT_SYSV"
    grep -Fq '/usr/sbin/minios-initramfs-shutdown auto || true' "$DRACUT_SYSV"
    grep -Fq '[ "${INITRAMFS_BUILDER:-}" = "dracut" ]' "$CORE_INSTALL"
    grep -Fq 'minios-svc enable minios-dracut-shutdown' "$CORE_INSTALL"
}

@test "Devuan dracut handoff preserves the shutdown initramfs contract" {
    run sh -n "$HANDOFF"
    [ "$status" -eq 0 ]
    grep -Fq 'mount --rbind "$NEWROOT" "$NEWROOT"' "$HANDOFF"
    grep -Fq 'mount --make-rprivate /' "$HANDOFF"
    grep -Fq 'mount --rbind /dev "$NEWROOT/dev"' "$HANDOFF"
    grep -Fq 'mount --rbind /proc "$NEWROOT/proc"' "$HANDOFF"
    grep -Fq 'mount --rbind /sys "$NEWROOT/sys"' "$HANDOFF"
    grep -Fq 'mount --bind /run "$NEWROOT/run"' "$HANDOFF"
    grep -Fq '"$BUSYBOX" pivot_root . oldroot' "$HANDOFF"
    grep -Fq 'exec /shutdown "$ACTION"' "$HANDOFF"
}

@test "Devuan dracut handoff falls back when no shutdown initramfs exists" {
    run env runlevel=2 MINIOS_INITRAMFS_ROOT="$BATS_TEST_TMPDIR/missing" "$HANDOFF" auto
    [ "$status" -eq 1 ]

    run env MINIOS_INITRAMFS_ROOT="$BATS_TEST_TMPDIR/missing" "$HANDOFF" reboot
    [ "$status" -eq 1 ]
}
