#!/bin/bash
git submodule init
git submodule update
cd busybox
make  defconfig
make -j $(( $(nproc) + 1 ))
# make install
cd ..
