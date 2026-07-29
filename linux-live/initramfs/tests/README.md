# Initramfs Tests

Run `./run.sh` from this directory (or `linux-live/initramfs/tests/run.sh` from
the repository root). `--strict` turns any skipped optional layer into a
failure, which is suitable for CI that provisions all prerequisites.

The primary behavior and contract suite uses the distribution `bats`/`bats-core`
package only; no Bats extensions are required or vendored. On Debian, Ubuntu, or
Devuan CI install the complete optional stack with:

```sh
apt-get update && apt-get install -y bats shellcheck cpio initramfs-tools-core dracut-core qemu-system-x86 cryptsetup
```

Run the exact CI command `linux-live/initramfs/tests/run.sh --strict`. Normal
mode reports missing Bats, ShellCheck, image-inspection, or privileged LUKS
prerequisites as skips; strict mode fails on them.

When installed, the runner executes ShellCheck for `run.sh`. All test cases,
including image inspection and the privileged integration layer, are native
Bats tests. Initrd production scripts receive POSIX or Bash syntax checks in CI;
their dynamic command construction is not broadly suppressed from ShellCheck.

`persistence_behavior.bats` tests LiveKit's shared persistence dispatcher:
native, raw, DynFileFS, unknown-mode native-to-DynFileFS compatibility, LUKS
failure fallback, and explicit owned-state cleanup. Both in-tree init and
shutdown implementations are checked for their shared-library and lifecycle
contracts, including legacy loop detachment that excludes the recorded LUKS
loop. The separately packaged `minios-dracut` mirror has its own release tests.
`crypt_perch_integration.bats`
is a real, privileged LUKS grow and remount test. It uses the bundled musl crypto
payload by default and falls back to system tools if that payload is absent; it
skips unless root and loop support are available. Set
`MINIOS_REQUIRE_CRYPT_TEST=1` or use `run.sh --strict` to require it.

`image_contents.bats` generates a minimal uncompressed `cpio` fixture when no
image is provided. To inspect a built image instead, set
`MINIOS_INITRD_IMAGE=/path/to/initrd`; set `MINIOS_EXPECT_CRYPT=1` for a
`--crypt` image. The test uses `lsinitramfs`, `lsinitrd`, or uncompressed
`cpio` images, whichever is available.
