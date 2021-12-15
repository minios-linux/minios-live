#!/usr/bin/python3
# Dockerfile.py

import sys
import logging
import pydocker  # github.com/jen-soft/pydocker

logging.getLogger('').setLevel(logging.INFO)
logging.root.addHandler(logging.StreamHandler(sys.stdout))

class DockerFile(pydocker.DockerFile):
    """   add here your custom features   """

d = DockerFile(base_img='ubuntu:rolling', name='local/mlc-rolling:latest')
d = DockerFile(base_img='ubuntu:rolling', name='local/mlc:latest')

d.RUN_bash_script('/opt/install.sh', r'''
touch /.minios-live-container
apt-get update -y
apt-get install -y wget sudo debootstrap xorriso genisoimage binutils squashfs-tools grub-pc-bin grub-efi-amd64-bin dosfstools mtools xz-utils liblz4-tool zstd git
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
d.WORKDIR = '/build/minios-live'

d.CMD = ["/build/minios-live/install", "-"]

d.build_img()
