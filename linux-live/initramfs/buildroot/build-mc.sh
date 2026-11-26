#!/bin/sh
# Link unchanged Mini Commander sources with the configured Buildroot toolchain.
set -eu
export LC_ALL=C
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 BUILDROOT_OUTPUT MINI_COMMANDER_SOURCE DESTINATION" >&2
    exit 2
fi
out=$(realpath "$1")
src=$(realpath "$2")
dest=$(realpath -m "$3")
cc="$out/host/bin/i686-linux-gcc"
strip="$out/host/bin/i686-linux-strip"
readelf="$out/host/bin/i686-linux-readelf"
for tool in "$cc" "$strip" "$readelf"; do
    test -x "$tool" || { echo "Missing Buildroot tool: $tool" >&2; exit 1; }
done
for setting in BR2_i386 BR2_x86_i686 BR2_STATIC_LIBS BR2_TOOLCHAIN_EXTERNAL_BOOTLIN_X86_I686_MUSL_STABLE BR2_PACKAGE_NCURSES_WCHAR; do
    grep -qx "$setting=y" "$out/.config" || { echo "Missing setting: $setting" >&2; exit 1; }
done
sysroot=$("$cc" -print-sysroot)
test -f "$sysroot/usr/lib/libncursesw.a"
mkdir -p "$(dirname "$dest")"
tmp=$(mktemp "${dest}.XXXXXX")
trap 'rm -f -- "$tmp" "$tmp.header" "$tmp.elf"' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$src"
"$cc" -Os -ffunction-sections -fdata-sections -std=gnu99 \
    -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 \
    -I"$sysroot/usr/include/ncursesw" \
    mc.c cmd.c operations.c dialog.c filelist.c init.c panel.c ui.c view_edit.c progress.c \
    -static -Wl,--gc-sections -Wl,--build-id=none -lncursesw -o "$tmp"
"$strip" --strip-all --remove-section=.comment --remove-section=.note "$tmp"
"$readelf" -h "$tmp" >"$tmp.header"
grep -Eq 'Class:[[:space:]]+ELF32' "$tmp.header"
grep -Eq 'Machine:[[:space:]]+Intel 80386' "$tmp.header"
"$readelf" -l "$tmp" >"$tmp.elf"
"$readelf" -d "$tmp" >>"$tmp.elf"
if grep -Eq 'INTERP|\(NEEDED\)' "$tmp.elf"; then
    echo 'Mini Commander unexpectedly requires a dynamic loader or libraries' >&2
    exit 1
fi
chmod 755 "$tmp"
"$tmp" --help >/dev/null 2>&1
mv -f -- "$tmp" "$dest"
printf 'Built static i686/musl mc: %s (%s bytes)\n' "$dest" "$(wc -c <"$dest")"
