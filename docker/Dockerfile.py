#!/usr/bin/python3
# Dockerfile.py

import sys
import logging
import pydocker  # github.com/jen-soft/pydocker

logging.getLogger('').setLevel(logging.INFO)
logging.root.addHandler(logging.StreamHandler(sys.stdout))

class DockerFile(pydocker.DockerFile):
    """   add here your custom features   """

#d = DockerFile(base_img='ubuntu:focal', name='local/mlc:latest')
#d = DockerFile(base_img='ubuntu:bionic', name='local/mlc:latest')
d = DockerFile(base_img='debian:buster', name='local/mlc:latest')

d.RUN_bash_script('/opt/install.sh', r'''
touch /.minios-live-container
apt-get update -y
apt-get install -y wget sudo debootstrap xorriso genisoimage binutils squashfs-tools grub-pc-bin grub-efi-amd64-bin dosfstools mtools xz-utils liblz4-tool zstd
: 'apt-get install -y patch
cd /opt/
wget -c http://ru.archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.123ubuntu2_all.deb
dpkg -i /opt/debootstrap_1.0.123ubuntu2_all.deb
rm -f /opt/debootstrap_1.0.123ubuntu2_all.deb
cat <<'EOF' >/usr/share/debootstrap/functions.diff
--- functions	2020-10-23 20:42:16.000000000 +0300
+++ functions.new	2021-01-16 23:22:25.612064306 +0300
@@ -1176,7 +1176,9 @@
 		umount_on_exit /dev/shm
 		umount_on_exit /proc
 		umount_on_exit /proc/bus/usb
-		umount "$TARGET/proc" 2>/dev/null || true
+		if [ ! -h "$TARGET/proc" ]; then
+			umount "$TARGET/proc" 2>/dev/null || true
+		fi
 
 		# some container environment are used at second-stage, it already treats /proc and so on
 		if [ -z "$(ls -A "$TARGET/proc")" ]; then

EOF
cd /usr/share/debootstrap/
patch </usr/share/debootstrap/functions.diff '
apt-get clean
find /var/log/ -type f | xargs rm -f
rm -f /var/backups/*
rm -f /var/cache/ldconfig/*
rm -f /var/cache/debconf/*
rm -f /var/cache/fontconfig/*
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/*.bin
rm -f /var/cache/debconf/*-old
rm -f /var/lib/apt/extended_states
rm -f /var/lib/apt/lists/*Packages*
rm -f /var/lib/apt/lists/*Translation*
rm -f /var/lib/apt/lists/*InRelease
rm -f /var/lib/apt/lists/deb.*
rm -f /var/lib/dpkg/*-old
''')

d.VOLUME = '/build'
d.WORKDIR = '/build/minios-slax'

d.CMD = ["/build/minios-slax/install", "-"]

d.build_img()
