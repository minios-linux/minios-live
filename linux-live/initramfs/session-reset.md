# Resetting an incompatible persistence session

The interactive incompatible-session menu offers four actions:

1. `No, return to session list`: return to the list (the initial selection).
2. `Yes, proceed at my own risk`: continue without changing the session.
3. `Reset, keep settings`: reset programs, retaining settings and data.
4. `Reset, keep data`: reset programs and system settings, retaining user data.

Automatic resume keeps its existing behavior. It does not silently reset an
incompatible session.

## Scope

The reset runs before the session is attached to the root union. Its only data
mutation target is the mounted session payload (`CHANGES`). Native persistence
uses the bind-mounted selected session; container backends use their mounted
inner filesystem. The root union, other sessions, and base modules are not
cleanup targets. Base-module dpkg lists are read only.

An OverlayFS session is read from its `changes/` subdirectory. A fresh upper is
constructed for the current union backend, without carrying AUFS whiteouts,
OverlayFS device whiteouts, opaque directory attributes, or the old workdir.
Symlinks are copied as symlinks and never traversed. Nested mounts are rejected.

Both modes remove system binary/library trees, system-wide Flatpak/Snap
installations, package-manager state,
and caches. Dpkg file lists from the old upper and current modules identify
package-owned software elsewhere. Unlisted files are retained conservatively;
there is no reliable generic identification of software installed manually in
arbitrary directories. User-created scripts are retained as user files.

`/home` and `/root` are retained in both modes, including hidden files, settings,
caches, browser profiles, and user-installed programs. They are not classified
by package ownership. Union whiteouts and special runtime nodes are normalized
as part of building a fresh union layer, rather than carried as user files.

Data can survive outside home directories, including `/srv`, application data
in `/var/lib`, `/var/spool`, `/var/www`, and unowned files elsewhere. A package
listing a directory does not authorize deleting its user-created contents.

## Settings and live-config

The settings-preserving mode retains `/etc` configuration, home configuration,
and package conffiles outside `/etc`. OS release/branding files, alternatives,
init scripts, and generated linker state are reset to the current image.

The data mode additionally discards ordinary `/etc` configuration and package
conffiles outside home trees. User settings in `/home` and `/root` survive even
in this mode: resetting them could also destroy passwords, bookmarks, databases,
or other user data.

Both modes keep account databases, UID/GID mappings, passwords, SSH host keys,
and private TLS keys. These are identity needed to access retained data, not a
request to recreate accounts with default credentials.

`/var/lib/live/config` is handled separately:

- Account-creation markers (`user-setup`, `root-setup`,
  `live-debconfig_passwd`) and the authorized-keys synchronization timestamp
  survive in both modes with their retained data.
- Home-configuration markers (XFCE panel, GNOME, KDE and screensavers) survive in
  both modes, preventing default configuration from overwriting retained homes.
- System-configuration markers, including network setup, survive only when
  system settings survive. The data mode allows those components to configure
  fresh system defaults.
- Package-manager/hook and generated-locale markers are discarded.

The existing live-config scripts require no new global skip switch. In
particular, root setup must not rerun and copy `/etc/skel` over retained root
files or reset credentials.

## Failure and persistence

A candidate tree is built inside the mounted session before moving original
data. This needs free space for a second copy of the retained data. A journal
and the old payload remain until the session metadata is committed. Copy/move
failure rolls back; an interrupted operation is recovered on the next mount.
Metadata rollback stops that activation so the next selection sees the restored
compatibility information. Recovery also invalidates the JSON metadata mirror.

For native sessions, reset disables `perchtoram` for that boot: the existing
native-to-RAM route creates an empty container and cannot retain the source
data. Other backends retain their normal RAM-copy behavior.

SquashFS reset changes only the restored RAM upper. The immutable `changes.sb`
is retained until a normal MiniOS Tools save publishes a new generation. Its
old compatibility fields remain valid for that snapshot. Boot-scoped reset
metadata updates version/edition only when the saver publishes the reset upper
from the same boot; older reset intent is ignored. Save the session manually,
or use its shutdown-save policy, to make the reset durable.

The SquashFS behavior requires the corresponding MiniOS Tools saver update as
well as the updated initrd.
