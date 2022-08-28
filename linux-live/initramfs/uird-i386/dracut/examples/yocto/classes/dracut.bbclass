DRACUT_PN ??= "${PN}"

def dracut_compression_type(d):
    rdtype = d.getVar("INITRAMFS_FSTYPES", True).split('.')
    if len(rdtype) != 2:
        return ['','','']
    if rdtype[0] != 'cpio':
        return ['','','']
    cmptypes = [['gz','--gzip','gzip'],['bz2', '--bzip2','bzip2'],['lzma','--lzma','xz'],['xz','--xz','xz'],['lzo','--lzo','lzo'],['lz4','--lz4','lz4'],['zstd','--zstd','zstd']]
    for cmp in cmptypes:
        if rdtype[1] == cmp[0]:
            return cmp
    return ['','','']

def dracut_compression_opt(d):
    cmp = dracut_compression_type(d)
    return cmp[1]

def dracut_compression_pkg(d):
    cmp = dracut_compression_type(d)
    return cmp[2]

def dracut_compression_pkg_native(d):
    cmp = dracut_compression_type(d)
    if cmp[2] == '':
        return ''
    return cmp[2] + '-native'

DRACUT_COMPRESS_OPT ??= "${@dracut_compression_opt(d)}"
DRACUT_COMPRESS_PKG ??= "${@dracut_compression_pkg(d)}"
DRACUT_COMPRESS_PKG_NATIVE ??= "${@dracut_compression_pkg_native(d)}"

DRACUT_OPTS ??= "--early-microcode ${DRACUT_COMPRESS_OPT}"

python __anonymous () {
    pkg = d.getVar("DRACUT_PN", True)
    if pkg != 'dracut':
        d.appendVar("RDEPENDS_%s" % pkg, " dracut %s " % d.getVar("DRACUT_COMPRESS_PKG", True))
    if not pkg.startswith('kernel'):
        d.appendVarFlag("do_configure", "depends", "virtual/kernel:do_shared_workdir")
        d.appendVarFlag("do_compile", "depends", "virtual/kernel:do_compile_kernelmodules")
}

export BUILD_TIME_KERNEL_VERSION = "${@oe.utils.read_file('${STAGING_KERNEL_BUILDDIR}/kernel-abiversion')}"

dracut_postinst () {
	MY_KERNEL_VERSION=$(readlink $D/boot/bzimage | sed 's,^.*bzImage-,,')
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		MY_KERNEL_VERSION="${KERNEL_VERSION}"
	fi
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		MY_KERNEL_VERSION="${BUILD_TIME_KERNEL_VERSION}"
	fi
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		exit 1
	fi

	if [ -n "$D" ]; then
		#DEBUGOPTS="--debug --keep"
		DEBUGOPTS="--keep"

		$INTERCEPT_DIR/postinst_intercept execute_dracut ${PKG} mlprefix=${MLPREFIX} \
			prefix= \
			MY_KERNEL_VERSION=$MY_KERNEL_VERSION \
			DEBUGOPTS="\"$DEBUGOPTS\"" \
			DRACUT_OPTS="\"${DRACUT_OPTS}\"" \
			systemdutildir=${systemd_unitdir} \
			systemdsystemunitdir=${systemd_system_unitdir} \
			systemdsystemconfdir=${sysconfdir}/systemd/system \
			udevdir=${libdir}/udev \
			DRACUT_TMPDIR=${WORKDIR}/dracut-tmpdir \
			DRACUT_ARCH="${TUNE_ARCH}" \
			DRACUT_COMPRESS_GZIP=$NATIVE_ROOT${bindir}/gzip \
			DRACUT_COMPRESS_BZIP2=$NATIVE_ROOT${bindir}/bzip2 \
			DRACUT_COMPRESS_LZMA=$NATIVE_ROOT${bindir}/lzma \
			DRACUT_LDD="\"PATH='$PATH' ${STAGING_BINDIR_CROSS}/ldd --root $D\"" \
			DRACUT_LDCONFIG=$NATIVE_ROOT${bindir}/ldconfig \
			DRACUT_INSTALL="\"$NATIVE_ROOT${libdir}/dracut/dracut-install\"" \
			PLYMOUTH_LDD="\"${STAGING_BINDIR_CROSS}/ldd --root $D\"" \
			PLYMOUTH_LDD_PATH="'$PATH'" \
			PLYMOUTH_PLUGIN_PATH=${libdir}/plymouth \
			PLYMOUTH_THEME_NAME=${PLYMOUTH_THEME_NAME:-spinner} \
			PLYMOUTH_THEME=${PLYMOUTH_THEME_NAME:-spinner}
	else
		depmod -a $MY_KERNEL_VERSION
		echo RUNNING: dracut -f ${DRACUT_OPTS} /boot/initramfs.img $MY_KERNEL_VERSION
		echo "dracut: $(dracut --help | grep 'Version:')"
		dracut -f ${DRACUT_OPTS} /boot/initramfs.img $MY_KERNEL_VERSION
	fi
}

dracut_populate_packages[vardeps] += "dracut_postinst"

python dracut_populate_packages() {
    localdata = d.createCopy()

    pkg = d.getVar('DRACUT_PN', True)

    postinst = d.getVar('pkg_postinst_%s' % pkg, True)
    if not postinst:
        postinst = '#!/bin/sh\n'
    postinst += localdata.getVar('dracut_postinst', True)
    d.setVar('pkg_postinst_%s' % pkg, postinst)
}

PACKAGESPLITFUNCS_prepend = "dracut_populate_packages "

DRACUT_DEPENDS = " \
			binutils-cross-${TUNE_ARCH} gcc-cross-${TUNE_ARCH} \
			ldconfig-native coreutils-native findutils-native \
			cpio-native util-linux-native kmod-native ${DRACUT_COMPRESS_PKG_NATIVE} \
			dracut-native pkgconfig-native cross-compiler-ldd \
			${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'systemd', '', d)} \
		"
DEPENDS_append_class-target = " ${DRACUT_DEPENDS}"
PACKAGE_WRITE_DEPS_append = " ${DRACUT_DEPENDS}"
