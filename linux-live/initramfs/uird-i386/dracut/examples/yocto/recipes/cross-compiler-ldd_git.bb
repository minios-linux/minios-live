SUMMARY = "Cross-compiler LDD"
HOMEPAGE = "https://gist.github.com/c403786c1394f53f44a3b61214489e6f"
BUGTRACKER = ""
LICENSE = "GPLv2"

LIC_FILES_CHKSUM = "file://cross-compile-ldd;beginline=53;endline=57;md5=2b29d19d18a430b931dda3750e865c84"

SRCBRANCH = "master"
SRCREV = "eb44581caf7dd60b149a6691abef46264c46e866"
SRC_URI = " \
			git://gist.github.com/c403786c1394f53f44a3b61214489e6f.git;protocol=https;branch=${SRCBRANCH} \
			file://cross-compile-ldd-fix-infinite-loop.patch \
		"

S = "${WORKDIR}/git"

inherit siteinfo

SYSROOT_PREPROCESS_FUNCS += " cross_ldd_populate_sysroot "

cross_ldd_populate_sysroot() {
	mkdir -p ${SYSROOT_DESTDIR}${bindir_crossscripts}
	cat ${S}/cross-compile-ldd | \
		sed \
			-e "s,^prefix=.*$,prefix=${TARGET_SYS}," \
			-e "s,^bits=.*$,bits=${SITEINFO_BITS}," \
			-e "s,^ld_library_path=.*$,ld_library_path=${LD_LIBRARY_PATH:-/lib:/usr/lib}," \
		>${SYSROOT_DESTDIR}${bindir_crossscripts}/ldd
	chmod +x ${SYSROOT_DESTDIR}${bindir_crossscripts}/ldd
}

DEPENDS = "coreutils-native sed-native binutils-cross-${TARGET_ARCH} gcc-cross-${TARGET_ARCH}"
PACKAGE_WRITE_DEPS = "coreutils-native sed-native binutils-cross-${TARGET_ARCH} gcc-cross-${TARGET_ARCH}"
