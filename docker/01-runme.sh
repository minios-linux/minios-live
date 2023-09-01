#!/bin/bash
# It creates a local container that you can use to build minios-live

apt update && apt install -y docker.io
systemctl start docker
systemctl enable docker
docker build . -t local/mlc:latest