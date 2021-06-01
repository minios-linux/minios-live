#!/bin/bash
# Several packages need to be installed to use Dockerfile.py
# It creates a local container that you can use to build minios-live
apt install python3-pip
pip3 install pydocker
python3 ./Dockerfile.py