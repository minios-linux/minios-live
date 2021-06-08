#!/bin/bash
# Several packages need to be installed to use Dockerfile.py
# It creates a local container that you can use to build minios-live
apt install -y docker.io
systemctl start docker
systemctl enable docker
apt install -y python3-pip
pip3 install pydocker
python3 ./Dockerfile.py