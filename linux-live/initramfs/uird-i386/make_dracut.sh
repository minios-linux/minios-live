#!/bin/bash
# dracut 046
#git submodule init
#git submodule update
cd dracut
make clean
./configure --disable-documentation
make -j $(( $(nproc) + 1 ))
# make install
cd ..
