# MiniOS SYSLINUX menu

`linux-live/bootfiles/boot/syslinux/minios-menu.c32` is built from SYSLINUX
6.03, matching the existing bootfiles loader and COM32 libraries. It is used
for the MiniOS BIOS menu; `vesamenu.c32` remains the upstream module.

Rebuild from the repository root:

```sh
bash tools/build-syslinux-menu
```

Requires Bash, curl, tar/xz, patch, GNU make, GCC with i386 code generation,
and GNU binutils. The script verifies the pinned upstream archive SHA-256 and
links against the COM32 libraries already shipped in bootfiles. The upstream
archive includes the source and its GPL license notices.

The small `syslinux-visible-keys.patch` changes two behaviors:

- Any keypress cancels the initial countdown, including F1 and arrow keys that
  leave the selection unchanged.
- `MENU HIDDENKEY` bindings also work while the menu is visible. The standard
  configuration parser resolves their target labels as usual. MiniOS binds F2
  to a hidden `CONFIG` entry for language selection and Esc to a hidden return
  entry on that screen. No extra selectable rows are added to the boot modes.

Language selection and return use untimed configurations. The normal
`lang/<locale>.cfg` files retain an initial timeout for explicitly localized
media and installer compatibility; `lang/<locale>-interactive.cfg` includes
the same configuration and overrides `TIMEOUT` to zero.

## Verification

Run `bats linux-live/tests/boot_config.bats` for generated configurations,
locale encodings, help-page dimensions, and navigation targets.

`linux-live/tests/syslinux_menu.testo` exercises the BIOS menu with Testo 15
syntax. Supply `ISO` pointing to a newly built `syslinux-native` image and
`EVIDENCE` pointing to an existing screenshot directory, using Testo's
`--param NAME VALUE` options. Use a fresh task prefix and a dedicated allowed
sharing directory. Run `--dry` before the actual test and clean that prefix
after collecting evidence.

The scenario checks F1, F2, Escape, English/Russian switching, the Tab editor,
and the absence of a restarted countdown after navigating auxiliary screens.
It ends in the boot menu and does not test Linux startup.
