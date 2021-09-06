#!/bin/bash
docker run -d --name mlc --privileged -v /build:/build local/mlc
#docker run --rm -it --name mlc --privileged -v /build:/build local/mlc /build/minios-slax/install build_modules -
