#!/bin/bash
# Several packages need to be installed to use Dockerfile.py
# It creates a local container that you can use to build minios-live

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
apt update && apt install -y docker.io python3-pip
systemctl start docker
systemctl enable docker
pip3 install pydocker
python3 $SCRIPT_DIR/Dockerfile.py