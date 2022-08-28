#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
	return 0
}

depends() {
	# We depend on modules being loaded
	return 0
}

installkernel() {
	return 0
}

bins="$UIRD_BINS"
install() {
	local _i _progs _path _busybox _binaries
	#uird
	inst "$moddir/livekit/livekitlib" "/livekitlib"
	inst "$moddir/livekit/uird-init" "/uird-init"
	inst "$moddir/livekit/liblinuxlive" "/liblinuxlive"
	inst "$moddir/livekit/uird.scan" "/uird.scan"
	inst "$moddir/livekit/uird.freemedia" "/uird.freemedia"
	inst "$moddir/livekit/uird.shutdown" "/uird.shutdown"
	inst "$moddir/livekit/uird.toxzm_mode" "/uird.toxzm_mode"
#	inst "$moddir/livekit/shutdown" "/shutdown"
#	inst "$moddir/livekit/i18n/ru.mo" "/usr/share/locale/ru/LC_MESSAGES/uird.mo"

	#binaries
	#    inst "$moddir/bash-$(uname -i)" "/bin/bash"
	[ -x "$initdir/bin/bash" ] || inst $(type -p bash) "/bin/bash"
	inst $(type -p blkid) /sbin/blkid.real
	inst $(type -p losetup) /sbin/losetup.real

	_binaries=""
	for bin in $bins; do
		if which $bin; then
			_binaries="${_binaries} $bin"
		else
			echo "executable file:  $bin - not found" >>./not_found.log
		fi
	done

	for _i in $_binaries; do
		inst $(type -p "$_i") /sbin/$_i
	done
	#busybox
	#_busybox=$(type -p busybox.static || type -p busybox )
	if [ "$BINBUSYBOX" ] ; then
	    _busybox="$BINBUSYBOX"
	else
	    _busybox=./busybox/busybox
	fi
	inst $_busybox /usr/bin/busybox
	_progs=""
	_filter="bash sh lsmod insmod modprobe rmmod modinfo depmod"
	for _i in $($_busybox --list); do
		echo $_filter |grep -wq $_i || _progs="$_progs $_i"
	done

    for _i in $_progs; do
		_path=$(find_binary "$_i")
		[ -z "$_path" -o "$_path" = "$_i" ] && _path=/bin/$_i
		[[ -x $initdir/$_path ]] && continue
		ln_r /usr/bin/busybox "$_path"
	done
    for _m in $_filter ; do
	ln_r /bin/kmod "/sbin/$_m"
    done
	echo "version: $(date +%Y%m%d), built for kernel: $kernel" >$initdir/uird_version
	inst_hook cmdline 95 "$moddir/parse-root-uird.sh"
	inst_hook mount 99 "$moddir/mount-uird.sh"
	inst_hook shutdown 99 "$moddir/shutdown-uird.sh"
}
