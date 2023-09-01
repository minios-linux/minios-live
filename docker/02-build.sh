#!/bin/bash
docker run -d --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /build:/build local/mlc /build/minios-live/install -
