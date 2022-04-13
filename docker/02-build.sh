#!/bin/bash
docker run -d --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /build:/build local/mlc /build/minios-live/install -
#docker run -d --name mlc --privileged -v /build:/build local/mlc-rolling /build/minios-live/install -
