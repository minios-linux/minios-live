#!/bin/bash

TEST_DESCRIPTION="rpm integrity after dracut and kernel install"

test_check() {
    command -v rpm &>/dev/null && ( command -v yum || command -v dnf ) &>/dev/null
}

test_run() {
    set -x
    set -e
    export rootdir=$TESTDIR/root

    mkdir -p $rootdir

    mkdir -p "$rootdir/proc"
    mkdir -p "$rootdir/sys"
    mkdir -p "$rootdir/dev"
    mkdir -p "$rootdir/boot"

    trap 'ret=$?; [[ -d $rootdir ]] && { umount "$rootdir/proc"; umount "$rootdir/sys"; umount "$rootdir/dev"; rm -rf -- "$rootdir"; } || :; exit $ret;' EXIT
    trap '[[ -d $rootdir ]] && { umount "$rootdir/proc"; umount "$rootdir/sys"; umount "$rootdir/dev"; rm -rf -- "$rootdir"; } || :; exit 1;' SIGINT

    mount --bind /proc "$rootdir/proc"
    mount --bind /sys "$rootdir/sys"
    mount -t devtmpfs devtmpfs "$rootdir/dev"

    mkdir -p "$rootdir/$TESTDIR"
    cp --reflink=auto -a \
       "$TESTDIR"/dracut-[0-9]*.$(uname -m).rpm \
       "$TESTDIR"/dracut-network-[0-9]*.$(uname -m).rpm \
       "$rootdir/$TESTDIR/"
    . /etc/os-release
    dnf_or_yum=yum
    dnf_or_yum_cmd=yum
    command -v dnf >/dev/null && { dnf_or_yum="dnf"; dnf_or_yum_cmd="dnf --allowerasing"; }
    for (( i=0; i < 5 ; i++)); do
        $dnf_or_yum_cmd -v --nogpgcheck --installroot "$rootdir"/ --releasever "$VERSION_ID" --disablerepo='*' \
                        --enablerepo=fedora --enablerepo=updates --setopt=install_weak_deps=False \
                        install -y \
                        $dnf_or_yum \
                        passwd \
                        rootfiles \
                        systemd \
                        systemd-udev \
                        kernel \
                        kernel-core \
                        redhat-release \
                        device-mapper-multipath \
                        lvm2 \
                        mdadm \
                        bash \
                        iscsi-initiator-utils \
                        "$TESTDIR"/dracut-[0-9]*.$(uname -m).rpm \
                        ${NULL} && break
        #"$TESTDIR"/dracut-config-rescue-[0-9]*.$(uname -m).rpm \
            #"$TESTDIR"/dracut-network-[0-9]*.$(uname -m).rpm \
            #    ${NULL}
    done
    (( i < 5 ))

    cat >"$rootdir"/test.sh <<EOF
#!/bin/bash
set -x
export LC_MESSAGES=C
rpm -Va |& \
    grep -F \
       '85-display-manager.preset| /run| /var| /usr/lib/variant| /etc/machine-id| /etc/systemd/system/dbus-org.freedesktop.network1.service| /etc/systemd/system/dbus-org.freedesktop.resolve1.service| /etc/udev/hwdb.bin| /usr/share/info/dir.old' \
    &> /test.output

find / -xdev -type f -not -path '/var/*' \
  -not -path '/usr/lib/modules/*/modules.*' \
  -not -path '/etc/*-' \
  -not -path '/etc/.pwd.lock' \
  -not -path '/run/mount/utab' \
  -not -path '/test.sh' \
  -not -path '/test.output' \
  -not -path '/etc/nsswitch.conf.bak' \
  -not -path '/etc/iscsi/initiatorname.iscsi' \
  -not -path '/boot/*0-rescue*' \
  -not -path '/usr/share/mime/*' \
  -not -path '/etc/crypto-policies/*' \
  -not -path '/dev/null' \
  -not -path "/boot/loader/entries/\$(cat /etc/machine-id)-*" \
  -not -path "/boot/\$(cat /etc/machine-id)/*" \
  -not -path '/etc/openldap/certs/*' \
  -print0 | xargs -0 rpm -qf | \
  grep -F 'not owned' &>> /test.output || :
exit 0
EOF

    chmod 0755 "$rootdir/test.sh"

    chroot "$rootdir" /test.sh || :

    if [[ -s "$rootdir"/test.output ]]; then
        failed=1
        echo TEST Failed >&2
        cat "$rootdir"/test.output >&2
    fi

    umount "$rootdir/proc"
    umount "$rootdir/sys"
    umount "$rootdir/dev"

    [[ $failed ]] && return 1
    return 0

}

test_setup() {
    make -C "$basedir" DESTDIR="$TESTDIR/" rpm
    return 0
}

test_cleanup() {
    rm -fr -- "$TESTDIR"/*.rpm
    return 0
}

. $testdir/test-functions
