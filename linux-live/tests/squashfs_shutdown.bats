#!/usr/bin/env bats

setup() {
    ROOT="$BATS_TEST_DIRNAME/.."
    UNIT="$ROOT/scripts/00-core/rootcopy-install/usr/lib/systemd/system/minios-squashfs-shutdown-save.service"
    LINK="$ROOT/scripts/00-core/rootcopy-install/etc/systemd/system/multi-user.target.wants/minios-squashfs-shutdown-save.service"
    SYSV="$ROOT/scripts/00-core/rootcopy-install/etc/init.d/minios-squashfs-shutdown-save"
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
