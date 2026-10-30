#!/usr/bin/env bash
# Sets up a local patched python-validity checkout and virtual environment
# for pairing the sensor without altering system Python packages.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

echo "--> 1. Fetching python-validity..."
if [ ! -d "$ROOT/build/python-validity/.git" ]; then
    mkdir -p "$ROOT/build"
    git clone https://github.com/uunicorn/python-validity.git "$ROOT/build/python-validity"
    cd "$ROOT/build/python-validity"
    git apply "$ROOT/patches/python-validity/0001-Add-support-for-Validity-138a-0094-Lenovo-Yoga-910-IdeaPad.patch"
    echo "    Patches applied successfully."
else
    echo "    Already cloned at build/python-validity."
fi

echo "--> 2. Fetching Lenovo firmware..."
"$ROOT/tools/fetch-firmware.sh" "$ROOT/build/firmware"

echo "--> 3. Python virtualenv check..."
VENV_PATH="${VENV_PATH:-/tmp/venv-validity}"
if [ ! -f "$VENV_PATH/bin/python3" ]; then
    python3 -m venv "$VENV_PATH"
    "$VENV_PATH/bin/pip" install --quiet pyusb cryptography pyyaml
    echo "    Created venv at $VENV_PATH."
fi

echo
echo "--> Ready to pair! Run:"
echo "    sudo $VENV_PATH/bin/python3 $ROOT/tools/pair-sensor.py --python-validity $ROOT/build/python-validity --factory-reset"
