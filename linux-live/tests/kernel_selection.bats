#!/usr/bin/env bats

setup() {
    LIVE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    source "${LIVE_ROOT}/minioslib"
    KERNEL_FLAVOUR=none
    KERNEL_PACKAGE_VERSION=""
    KERNEL_SNAPSHOT_DATE=""
    KERNEL_UPDATE_POLICY=track
    WARNING=""
    ERROR=""
    warning() { WARNING="$1"; }
    error() { ERROR="$1"; }
}

make_grub_module_fixture() {
    local work="$1"
    mkdir -p "${work}/image/minios/boot/grub/x86_64-efi" \
        "${work}/image/minios/boot/grub/i386-efi"
    printf 'grub_package_version="2.12-test"\n' \
        >"${work}/image/minios/boot/grub/x86_64-efi/modinfo.sh"
    printf 'grub_package_version="2.06-test"\n' \
        >"${work}/image/minios/boot/grub/i386-efi/modinfo.sh"
}

@test "automatic Trixie i386 selection uses tracked Bookworm kernel" {
    DISTRIBUTION=trixie
    DISTRIBUTION_PROFILE=debian
    DISTRIBUTION_ARCH=i386
    DEFAULT_KERNEL_ARCH=686
    KERNEL_AUTO_SELECT=true
    KERNEL_ARCH=amd64
    KERNEL_DISTRIBUTION=sid
    KERNEL_PACKAGE_VERSION=wrong
    KERNEL_SNAPSHOT_DATE=wrong
    KERNEL_UPDATE_POLICY=frozen

    resolve_kernel_selection

    [ "${KERNEL_SOURCE_SUITE}" = bookworm ]
    [ "${KERNEL_ARCH}" = 686 ]
    [ "${KERNEL_APT_ARCH}" = i386 ]
    [ "${KERNEL_METAPACKAGE}" = linux-image-686 ]
    [ "${KERNEL_REQUEST}" = linux-image-686:i386 ]
    [ "${KERNEL_UPDATE_POLICY}" = track ]
}

@test "automatic i386-pae compatibility mapping selects Bookworm PAE" {
    DISTRIBUTION=sid
    DISTRIBUTION_PROFILE=debian
    DISTRIBUTION_ARCH=i386
    DEFAULT_KERNEL_ARCH=686-pae
    KERNEL_AUTO_SELECT=true
    KERNEL_ARCH=""
    KERNEL_DISTRIBUTION=""

    resolve_kernel_selection

    [ "${KERNEL_SOURCE_SUITE}" = bookworm ]
    [ "${KERNEL_METAPACKAGE}" = linux-image-686-pae ]
}

@test "unknown automatic flag warns and uses automatic selection" {
    DISTRIBUTION=noble
    DISTRIBUTION_PROFILE=ubuntu
    DISTRIBUTION_ARCH=amd64
    DEFAULT_KERNEL_ARCH=amd64
    KERNEL_AUTO_SELECT=invalid
    KERNEL_ARCH=""
    KERNEL_DISTRIBUTION=""

    resolve_kernel_selection

    [ "${KERNEL_AUTO_SELECT}" = true ]
    [ "${KERNEL_SOURCE_SUITE}" = noble ]
    [ "${KERNEL_METAPACKAGE}" = linux-image-generic ]
    [[ "${WARNING}" == *"invalid"* ]]
}

@test "manual selection keeps exact suite architecture version and policy" {
    DISTRIBUTION=trixie
    DISTRIBUTION_PROFILE=debian
    DISTRIBUTION_ARCH=i386
    DEFAULT_KERNEL_ARCH=686
    KERNEL_AUTO_SELECT=false
    KERNEL_DISTRIBUTION=bookworm
    KERNEL_ARCH=amd64
    KERNEL_PACKAGE_VERSION=6.1-test
    KERNEL_SNAPSHOT_DATE=""
    KERNEL_UPDATE_POLICY=frozen

    resolve_kernel_selection

    [ "${KERNEL_SOURCE_SUITE}" = bookworm ]
    [ "${KERNEL_APT_ARCH}" = amd64 ]
    [ "${KERNEL_REQUEST}" = linux-image-amd64:amd64=6.1-test ]
    [ "${KERNEL_UPDATE_POLICY}" = frozen ]
}

@test "Debian snapshot kernel acquisition disables Valid-Until checks" {
    acquire="${LIVE_ROOT}/scripts/01-kernel/acquire"
    body="$(awk '/^apt_options\(\)/,/^}/' "${acquire}")"

    run env KERNEL_SOURCE_FAMILY=debian KERNEL_SNAPSHOT_DATE=20200101T000000Z \
        APT_ROOT=/tmp/apt DOWNLOAD_DIR=/tmp/archives DISTRIBUTION_ARCH=amd64 KERNEL_APT_ARCH=amd64 \
        bash -c "${body}; apt_options"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *'Acquire::Check-Valid-Until=false'* ]]

    run env KERNEL_SOURCE_FAMILY=debian KERNEL_SNAPSHOT_DATE= \
        APT_ROOT=/tmp/apt DOWNLOAD_DIR=/tmp/archives DISTRIBUTION_ARCH=amd64 KERNEL_APT_ARCH=amd64 \
        bash -c "${body}; apt_options"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *'Acquire::Check-Valid-Until=false'* ]]
}

@test "kernel lock parser reads compact kernel object" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${WORK_DIR}/kernel"
    cat >"${WORK_DIR}/kernel.lock" <<'EOF'
{"format":1,"kernel":{"distribution":"bookworm","version":"6.1-test","package_architecture":"i386"}}
EOF

    [ "$(kernel_lock_value distribution)" = bookworm ]
    [ "$(kernel_lock_value version)" = 6.1-test ]
    [ "$(kernel_lock_value package_architecture)" = i386 ]
}

@test "kernel lock requires the matching published module" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    INSTALL_KERNEL=true
    KERNEL_SOURCE_FAMILY=debian
    KERNEL_SOURCE_SUITE=bookworm
    KERNEL_APT_ARCH=i386
    mkdir -p "${WORK_DIR}/kernel" "${WORK_DIR}/image/minios"
    cat >"${WORK_DIR}/kernel.lock" <<'EOF'
{"format":1,"kernel":{"distribution":"bookworm","version":"6.1-test","package_architecture":"i386"}}
EOF
    : >"${WORK_DIR}/kernel/vmlinuz-6.1-test"
    : >"${WORK_DIR}/kernel/config-6.1-test"

    ! validate_kernel_lock
    : >"${WORK_DIR}/image/minios/01-kernel-other.sb"
    ! validate_kernel_lock
    : >"${WORK_DIR}/image/minios/01-kernel-6.1-test.sb"
    validate_kernel_lock
    [ "${LOCKED_EFI_VENDOR}" = debian ]

    INSTALL_KERNEL=false
    rm -f "${WORK_DIR}/kernel.lock" "${WORK_DIR}/image/minios/01-kernel-"*.sb
    validate_kernel_lock
    [ "${LOCKED_EFI_VENDOR}" = debian ]
}

@test "EFI image builder publishes one minimal firmware-readable dual-architecture ESP" {
    command -v mformat >/dev/null
    command -v mcopy >/dev/null
    command -v minfo >/dev/null
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    LOCKED_EFI_VENDOR=debian
    EFI_X64_VENDOR=debian
    EFI_X64_SUITE=trixie
    EFI_X64_GRUB_VERSION=2.12
    EFI_IA32_VENDOR=debian
    EFI_IA32_SUITE=bookworm
    EFI_IA32_GRUB_VERSION=2.06
    mkdir -p "${WORK_DIR}/image/EFI/boot" "${WORK_DIR}/image/minios/boot/grub"
    make_grub_module_fixture "${WORK_DIR}"
    for file in bootia32.efi grubia32.efi bootx64.efi grubx64.efi; do
        printf '%s\n' "${file}" >"${WORK_DIR}/image/EFI/boot/${file}"
    done

    build_efi_images

    [ ! -e "${WORK_DIR}/image/minios/boot/grub/efi32.img" ]
    [ ! -e "${WORK_DIR}/image/minios/boot/grub/efi64.img" ]
    minfo -i "${WORK_DIR}/image/minios/boot/grub/efi.img" :: | grep -Eq 'disk type="FAT(12|16)[[:space:]]+"'
    mdir -i "${WORK_DIR}/image/minios/boot/grub/efi.img" ::/EFI/boot/bootx64.efi >/dev/null
    mdir -i "${WORK_DIR}/image/minios/boot/grub/efi.img" ::/EFI/boot/bootia32.efi >/dev/null
    local image="${WORK_DIR}/image/minios/boot/grub/efi.img"
    local smaller="${BATS_TEST_TMPDIR}/efi-smaller.img"
    local image_sectors="$(( $(stat -c %s "${image}") / 512 ))"
    local minimum_sectors
    minimum_sectors="$(minfo -i "${image}" :: | sed -n 's/^small size: \([0-9]*\) sectors$/\1/p')"
    [ "$((image_sectors % 4))" -eq 0 ]
    [ "$((image_sectors - minimum_sectors))" -ge 0 ]
    [ "$((image_sectors - minimum_sectors))" -lt 4 ]
    ! efi_image_fits "${smaller}" "${WORK_DIR}/image/EFI" "$((minimum_sectors - 1))"
    grep -Fq '"layout": "dual-architecture-esp"' "${WORK_DIR}/image/minios/boot/efi-manifest.json"
    grep -Fq '"x64": {"vendor":"debian","suite":"trixie","grub_version":"2.12"' "${WORK_DIR}/image/minios/boot/efi-manifest.json"
    grep -Fq '"ia32": {"vendor":"debian","suite":"bookworm","grub_version":"2.06"' "${WORK_DIR}/image/minios/boot/efi-manifest.json"
    grep -Fq '"modules_version":"2.12-test"' "${WORK_DIR}/image/minios/boot/efi-manifest.json"
    grep -Fq '"modules_version":"2.06-test"' "${WORK_DIR}/image/minios/boot/efi-manifest.json"
}

@test "EFI image builder bounds permanent formatter failures" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    mkdir -p "${WORK_DIR}/image/EFI/boot" "${WORK_DIR}/image/minios/boot/grub"
    make_grub_module_fixture "${WORK_DIR}"
    for file in bootia32.efi grubia32.efi bootx64.efi grubx64.efi; do
        printf '%s\n' "${file}" >"${WORK_DIR}/image/EFI/boot/${file}"
    done
    local payload_bytes expected_max probed_max=false
    payload_bytes="$(du -sb "${WORK_DIR}/image/EFI" | cut -f1)"
    expected_max="$(((payload_bytes * 2 + 64 * 1024 * 1024 + 511) / 512))"
    efi_image_fits() {
        [ "$3" -eq "${expected_max}" ] && probed_max=true
        return 1
    }

    ! build_efi_images

    [ "${probed_max}" = true ]
    [[ "${ERROR}" == Unable\ to\ create\ EFI\ image* ]]
    [ ! -e "${WORK_DIR}/image/minios/boot/grub/efi.img" ]
}

@test "hybrid ISO gives EFI and persistence distinct complete partitions" {
    command -v xorriso >/dev/null
    command -v mkfs.ext2 >/dev/null
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    LOCKED_EFI_VENDOR=debian
    EFI_X64_VENDOR=debian
    EFI_X64_SUITE=trixie
    EFI_X64_GRUB_VERSION=2.12
    EFI_IA32_VENDOR=debian
    EFI_IA32_SUITE=bookworm
    EFI_IA32_GRUB_VERSION=2.06
    mkdir -p "${WORK_DIR}/image/EFI/boot" \
        "${WORK_DIR}/image/minios/boot/grub" \
        "${WORK_DIR}/image/minios/boot/grub/i386-pc" \
        "${WORK_DIR}/image/minios/boot/syslinux"
    make_grub_module_fixture "${WORK_DIR}"
    for file in bootia32.efi grubia32.efi bootx64.efi grubx64.efi; do
        printf '%s\n' "${file}" >"${WORK_DIR}/image/EFI/boot/${file}"
    done
    cp "${LIVE_ROOT}/bootfiles/boot/syslinux/isolinux.bin" \
        "${LIVE_ROOT}/bootfiles/boot/syslinux/isohdpfx.bin" \
        "${WORK_DIR}/image/minios/boot/syslinux/"
    cp "${LIVE_ROOT}/bootfiles/boot/grub/i386-pc/boot_hybrid.img" \
        "${WORK_DIR}/image/minios/boot/grub/i386-pc/"
    truncate -s 2048 "${WORK_DIR}/image/minios/boot/grub/i386-pc/eltorito.img"
    build_efi_images

    CONTAINER=false
    DESKTOP_ENVIRONMENT=xfce
    DISTRIBUTION=trixie
    PACKAGE_VARIANT=standard
    LANGID=""
    RELEASE=true
    RELEASE_VERSION=test
    KERNEL_FLAVOUR=none
    KERNEL_AUFS=false
    BUILD_FROM_SNAPSHOT=false
    ISO_ARCH=amd64
    REMOVE_OLD_ISO=false
    VERBOSITY_LEVEL=1
    BUILD_TEST_ISO=false
    current_process() { :; }
    information() { :; }
    local image="${WORK_DIR}/image/minios/boot/grub/efi.img"
    local image_sectors="$(( $(stat -c %s "${image}") / 512 ))"
    local bootloader iso gpt_sectors
    for bootloader in syslinux-native grub-only; do
        BOOTLOADER="${bootloader}"
        ISO_DIR="${BATS_TEST_TMPDIR}/iso-${bootloader}"
        build_iso
        iso="${ISO_DIR}/minios-trixie-xfce-standard-amd64-test.iso"
        run xorriso -indev "${iso}" -report_system_area plain
        [ "${status}" -eq 0 ]
        grep -Eq '^MBR partition[[:space:]]+:[[:space:]]+2[[:space:]]+0x00[[:space:]]+0xef' <<<"${output}"
        grep -Eq '^MBR partition[[:space:]]+:[[:space:]]+3[[:space:]]+0x00[[:space:]]+0x83' <<<"${output}"
        gpt_sectors="$(sed -n 's/^GPT start and size :[[:space:]]*2[[:space:]]*[0-9][0-9]*[[:space:]]*\([0-9][0-9]*\)$/\1/p' <<<"${output}")"
        [ "${gpt_sectors}" -eq "${image_sectors}" ]
    done
}

@test "Debian EFI package contract splits Trixie x64 from Bookworm IA32" {
    source "${LIVE_ROOT}/efi-packages.conf"

    [ "${DEBIAN_X64_SUITE}" = trixie ]
    [ "${DEBIAN_X64_GRUB_VERSION}" = 2.12 ]
    [[ "${DEBIAN_X64_GRUB_URL}" == *grub-efi-amd64-signed_1+2.12*deb13u2_amd64.deb ]]
    [ "${DEBIAN_X64_GRUB_MODULES_VERSION}" = 2.12-9+deb13u2 ]
    [[ "${DEBIAN_X64_GRUB_MODULES_URL}" == *grub-efi-amd64-bin_2.12-9+deb13u2_amd64.deb ]]
    [ "${DEBIAN_IA32_SUITE}" = bookworm ]
    [ "${DEBIAN_IA32_GRUB_VERSION}" = 2.06 ]
    [[ "${DEBIAN_IA32_GRUB_URL}" == *grub-efi-ia32-signed_1+2.06*deb12u2_i386.deb ]]
    [ "${DEBIAN_IA32_GRUB_MODULES_VERSION}" = 2.06-13+deb12u2 ]
    [[ "${DEBIAN_IA32_GRUB_MODULES_URL}" == *grub-efi-ia32-bin_2.06-13+deb12u2_amd64.deb ]]
}

@test "shim vendor CA inspection does not rewrite the signed input" {
    command -v objcopy >/dev/null
    command -v openssl >/dev/null
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${WORK_DIR}"
    local shim="${BATS_TEST_TMPDIR}/shim" ca="${BATS_TEST_TMPDIR}/ca.pem"
    local der="${BATS_TEST_TMPDIR}/ca.der" section="${BATS_TEST_TMPDIR}/vendor-cert"
    local size before after
    openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=minios-test -days 1 \
        -keyout "${BATS_TEST_TMPDIR}/ca.key" -out "${ca}" >/dev/null 2>&1
    openssl x509 -in "${ca}" -outform DER -out "${der}"
    size="$(stat -c %s "${der}")"
    printf "\\$(printf '%03o' $((size & 255)))\\$(printf '%03o' $(((size >> 8) & 255)))\\$(printf '%03o' $(((size >> 16) & 255)))\\$(printf '%03o' $(((size >> 24) & 255)))" >"${section}"
    dd if=/dev/zero bs=1 count=12 status=none >>"${section}"
    cat "${der}" >>"${section}"
    objcopy --add-section .vendor_cert="${section}" /bin/true "${shim}"
    before="$(sha256sum "${shim}" | cut -d' ' -f1)"

    verify_shim_vendor_ca "${shim}" "${ca}"

    after="$(sha256sum "${shim}" | cut -d' ' -f1)"
    [ "${after}" = "${before}" ]
}

@test "initrd builder keeps kernel metadata out of the boot directory" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    INSTALL_KERNEL=true
    NAMED_BOOT_FILES=true
    KERNEL=6.1-test
    BUILD_SCRIPTS=build-scripts
    mkdir -p "${WORK_DIR}/kernel" "${WORK_DIR}/image/minios/boot"
    printf '%s\n' kernel >"${WORK_DIR}/kernel/vmlinuz-${KERNEL}"
    printf '%s\n' CONFIG_EFI_STUB=y >"${WORK_DIR}/kernel/config-${KERNEL}"
    printf '%s\n' stale >"${WORK_DIR}/image/minios/boot/config-stale"
    printf '%s\n' stale >"${WORK_DIR}/image/minios/boot/System.map-stale"
    current_function() { :; }
    overlay_cleanup() { :; }
    overlay_chroot_mount_fs() { mkdir -p "${OVERLAY[merged]}/boot"; }
    read_config() { :; }
    copy_build_scripts() {
        mkdir -p "$1/${BUILD_SCRIPTS}"
        printf '%s\n' '#!/bin/sh' >"$1/${BUILD_SCRIPTS}/build-initramfs"
    }
    chroot_run() {
        cp "${OVERLAY[upper]}/boot/"* "${OVERLAY[merged]}/boot/"
        : >"${OVERLAY[merged]}/boot/initrfs.img"
    }
    overlay_chroot_finish_up() { :; }
    overlay_unmount_dirs() { :; }

    build_initrd

    ! compgen -G "${WORK_DIR}/image/minios/boot/config-*"
    ! compgen -G "${WORK_DIR}/image/minios/boot/System.map-*"
}

@test "rebuilding a middle module removes that module and every higher layer" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    ENVIRONMENTS="${BATS_TEST_TMPDIR}/environment"
    mkdir -p "${WORK_DIR}/image/minios" "${ENVIRONMENTS}"
    for module in 01-kernel 02-firmware 03-gui-base 04-desktop 05-apps; do
        mkdir -p "${ENVIRONMENTS}/${module}"
        touch "${WORK_DIR}/image/minios/${module}-test.sb"
    done

    remove_module_chain_from 03-gui-base

    [ -f "${WORK_DIR}/image/minios/01-kernel-test.sb" ]
    [ -f "${WORK_DIR}/image/minios/02-firmware-test.sb" ]
    [ ! -e "${WORK_DIR}/image/minios/03-gui-base-test.sb" ]
    [ ! -e "${WORK_DIR}/image/minios/04-desktop-test.sb" ]
    [ ! -e "${WORK_DIR}/image/minios/05-apps-test.sb" ]
}

@test "module freshness follows environment symlink targets without deleting artifacts" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    BUILD_SCRIPTS_DIR="${BATS_TEST_TMPDIR}/linux-live"
    BUILD_CONF="${BATS_TEST_TMPDIR}/build.conf"
    ENVIRONMENTS="${BUILD_SCRIPTS_DIR}/environments/xfce"
    mkdir -p "${WORK_DIR}/image/minios" "${ENVIRONMENTS}" \
        "${BUILD_SCRIPTS_DIR}/scripts/10-shared"
    : >"${BUILD_SCRIPTS_DIR}/condinapt"
    : >"${BUILD_SCRIPTS_DIR}/condinapt.map"
    : >"${BUILD_CONF}"
    ln -s ../../scripts/10-shared "${ENVIRONMENTS}/03-shared"
    : >"${BUILD_SCRIPTS_DIR}/scripts/10-shared/install"
    : >"${WORK_DIR}/image/minios/03-shared-amd64.sb"
    touch -d '2 minutes ago' "${WORK_DIR}/image/minios/03-shared-amd64.sb"
    touch "${BUILD_SCRIPTS_DIR}/scripts/10-shared/install"

    ! module_artifact_is_current 03-shared
    [ -f "${WORK_DIR}/image/minios/03-shared-amd64.sb" ]
}

@test "non-kernel module freshness includes the shared minioslib" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    BUILD_SCRIPTS_DIR="${BATS_TEST_TMPDIR}/linux-live"
    ENVIRONMENTS="${BUILD_SCRIPTS_DIR}/environments/xfce"
    mkdir -p "${WORK_DIR}/image/minios" "${ENVIRONMENTS}/03-gui-base"
    : >"${BUILD_SCRIPTS_DIR}/condinapt"
    : >"${BUILD_SCRIPTS_DIR}/condinapt.map"
    : >"${BUILD_SCRIPTS_DIR}/minioslib"
    : >"${WORK_DIR}/image/minios/03-gui-base-amd64.sb"
    touch -d '2 minutes ago' "${WORK_DIR}/image/minios/03-gui-base-amd64.sb"
    touch "${BUILD_SCRIPTS_DIR}/minioslib"

    ! module_artifact_is_current 03-gui-base
}

@test "duplicate module artifacts are rejected and all removed" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    BUILD_SCRIPTS_DIR="${BATS_TEST_TMPDIR}/linux-live"
    ENVIRONMENTS="${BUILD_SCRIPTS_DIR}/environments/xfce"
    mkdir -p "${WORK_DIR}/image/minios" "${ENVIRONMENTS}/03-apps"
    : >"${BUILD_SCRIPTS_DIR}/condinapt"
    : >"${BUILD_SCRIPTS_DIR}/condinapt.map"
    : >"${BUILD_SCRIPTS_DIR}/minioslib"
    : >"${WORK_DIR}/image/minios/03-apps-old.sb"
    : >"${WORK_DIR}/image/minios/03-apps-new.sb"
    : >"${WORK_DIR}/image/minios/03-myapps.sb"

    ! module_artifact_is_current 03-apps
    remove_module_artifact 03-apps

    [ ! -e "${WORK_DIR}/image/minios/03-apps-old.sb" ]
    [ ! -e "${WORK_DIR}/image/minios/03-apps-new.sb" ]
    [ -e "${WORK_DIR}/image/minios/03-myapps.sb" ]
}

@test "module chain removal matches exact module names" {
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    LIVEKITNAME=minios
    BEXT=sb
    ENVIRONMENTS="${BATS_TEST_TMPDIR}/environment"
    mkdir -p "${WORK_DIR}/image/minios" "${ENVIRONMENTS}/03-apps" "${ENVIRONMENTS}/04-desktop"
    : >"${WORK_DIR}/image/minios/03-apps-amd64.sb"
    : >"${WORK_DIR}/image/minios/03-myapps-amd64.sb"
    : >"${WORK_DIR}/image/minios/04-desktop-amd64.sb"

    remove_module_chain_from 03-apps

    [ ! -e "${WORK_DIR}/image/minios/03-apps-amd64.sb" ]
    [ -e "${WORK_DIR}/image/minios/03-myapps-amd64.sb" ]
    [ ! -e "${WORK_DIR}/image/minios/04-desktop-amd64.sb" ]
}

@test "verified EFI copy rejects a corrupted destination" {
    local manifest="${BATS_TEST_TMPDIR}/manifest.json"
    local source="${BATS_TEST_TMPDIR}/source" destination="${BATS_TEST_TMPDIR}/destination"
    printf source >"${source}"
    printf '{"files":{"loader":"%s"}}\n' "$(sha256sum "${source}" | cut -d' ' -f1)" >"${manifest}"
    cp() {
        printf corrupted >"$3"
        return 0
    }

    ! copy_verified_manifest_file "${manifest}" loader "${source}" "${destination}"
}

@test "module overlay mounts immutable squashfs lower layers read-only" {
    grep -Fq 'mount -o ro "${MODULES[$i]}" "${OVERLAYS}/bundles/${BUNDLE}"' \
        "${BATS_TEST_DIRNAME}/../minioslib"
}
