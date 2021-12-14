#!/bin/bash
docker run -d --name mlc --privileged -v /build:/build local/mlc /build/minios-live/install -
#docker run -d --name mlc --privileged -v /build:/build local/mlc-rolling /build/minios-live/install -
