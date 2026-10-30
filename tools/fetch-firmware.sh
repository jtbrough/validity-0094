#!/usr/bin/env bash
# Downloads and extracts the official Lenovo extension firmware (6_07f_Lenovo.xpfwext)
# directly from Lenovo's CDN without distributing proprietary blobs.
set -euo pipefail

LENOVO_URI="https://download.lenovo.com/pccbbs/mobiles/n1cgn08w.exe"
EXPECTED_SHA512="d839fa65adf4c952ecb4a5c4b2fc5b5bdedd8e02a421564bdc7fae1d281be4ea26fcde2333f2ab78d56cef0fdccce0a3cf429300b89544cdc9cfee6d0fe0db55"
FIRMWARE_NAME="6_07f_Lenovo.xpfwext"
OUT_DIR="${1:-.}"

if ! command -v innoextract >/dev/null 2>&1; then
    echo "Error: 'innoextract' is required. Install via package manager or homebrew." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "--> Downloading official Lenovo ThinkPad driver package..."
curl -sSL --retry 3 "$LENOVO_URI" -o "$TMP_DIR/installer.exe"

echo "--> Verifying SHA-512 checksum..."
ACTUAL_SHA512=$(sha512sum "$TMP_DIR/installer.exe" | awk '{print $1}')
if [ "$ACTUAL_SHA512" != "$EXPECTED_SHA512" ]; then
    echo "Error: SHA-512 mismatch!" >&2
    echo "Expected: $EXPECTED_SHA512" >&2
    echo "Got:      $ACTUAL_SHA512" >&2
    exit 1
fi

echo "--> Extracting $FIRMWARE_NAME via innoextract..."
innoextract --output-dir "$TMP_DIR/out" --include "$FIRMWARE_NAME" "$TMP_DIR/installer.exe" >/dev/null

EXTRACTED=$(find "$TMP_DIR/out" -name "$FIRMWARE_NAME" | head -n 1)
if [ -z "$EXTRACTED" ] || [ ! -f "$EXTRACTED" ]; then
    echo "Error: Failed to find $FIRMWARE_NAME in extracted archive" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
cp "$EXTRACTED" "$OUT_DIR/$FIRMWARE_NAME"
echo "--> Successfully saved firmware to: $OUT_DIR/$FIRMWARE_NAME"
