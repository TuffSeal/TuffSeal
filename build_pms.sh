#!/bin/bash
# BUILD_PMS.sh -> building packmyseal pms from pms.py (Linux)

set -e

python3 -m pip install --upgrade pip
python3 -m pip install pyinstaller requests

pyinstaller \
  --noconfirm \
  --onefile \
  --console \
  --hidden-import requests \
  pms.py
