#!/usr/bin/env bash
# Installs compiled libfprint-2.so.2.0.0 and udev rules into system paths.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: installation requires root privileges. Run with sudo." >&2
    exit 1
fi

LIB_SRC=""
for candidate in "$ROOT/dist/libfprint-2.so.2.0.0" "$ROOT/build/libfprint-2.so.2.0.0" "$ROOT/libfprint-2.so.2.0.0"; do
    if [ -f "$candidate" ]; then
        LIB_SRC="$candidate"
        break
    fi
done

if [ -z "$LIB_SRC" ]; then
    echo "Error: compiled libfprint-2.so.2.0.0 not found." >&2
    exit 1
fi

# Detect target library directory
if [ -d "/usr/lib64" ]; then
    LIB_DEST="/usr/lib64"
elif [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    LIB_DEST="/usr/lib/x86_64-linux-gnu"
else
    LIB_DEST="/usr/lib"
fi

echo "--> Installing $LIB_SRC to $LIB_DEST/libfprint-2.so.2.0.0..."
cp "$LIB_SRC" "$LIB_DEST/libfprint-2.so.2.0.0"
chmod 0755 "$LIB_DEST/libfprint-2.so.2.0.0"

# Detect target udev rules directory
UDEV_DEST="/usr/lib/udev/rules.d"
if [ ! -d "$UDEV_DEST" ]; then
    UDEV_DEST="/etc/udev/rules.d"
fi
mkdir -p "$UDEV_DEST"

echo "--> Installing udev rules to $UDEV_DEST..."
cp "$ROOT"/udev/*.rules "$UDEV_DEST/"
chmod 0644 "$UDEV_DEST"/60-libfprint-2-vfs0090.rules "$UDEV_DEST"/99-validity-0094-no-autosuspend.rules

echo "--> Reloading udev rules..."
udevadm control --reload || true
udevadm trigger --subsystem-match=usb --attr-match=idVendor=138a || true

echo "--> Restarting fprintd..."
systemctl restart fprintd || true

echo "--> Installation complete! Enrol a finger using:"
echo "    fprintd-enroll -f right-index-finger"
