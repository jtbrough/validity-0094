# Validity 138a:0094 Linux Driver & Pairing

Linux driver patches and pairing tooling for the **Validity Sensors, Inc. 138a:0094** fingerprint reader (Lenovo IdeaPad FLEX 4, Yoga 910/720, and IdeaPad Air 13 Pro).

Enables match-on-host fingerprint authentication via standard `libfprint` and `fprintd`.

---

## Hardware

| Field | Detail |
| :--- | :--- |
| **USB ID** | `138a:0094` |
| **Vendor** | Validity Sensors, Inc. (Synaptics) |
| **Model** | VFS7552 (Prometheus family) |
| **ROM** | `v6.7 (build 164)` |
| **Mode** | Match-on-Host (144×144 8bpp raw frame, host matching via Bozorth3) |
| **Sibling** | Identical ROM and signed extension firmware (`6_07f_Lenovo.xpfwext`) to ThinkPad `138a:0090` |

---

## Protocol Differences (vs 138a:0090)

1. **Unsigned Partition Table:**
   The ThinkPad `0090` expects an RSA signature appended to the partition table during flash init. The `0094` rejects any appended RSA signature with error `0x04af`; it requires `signature = b''`.
2. **Flash Layout:**
   Template database size in flash is `0xb0000` (vs `0x30000` on `0090`).
3. **Class Features Initialization (`libfprint >= 1.94`):**
   `vfs0090` predates `cls->features` enforcement. Calling `fpi_device_class_auto_initialize_features(dev_class)` in `fpi_device_vfs0090_class_init` prevents assertion failure on driver load.

---

## Repository Layout

```
├── patches/
│   ├── python-validity/
│   │   └── 0001-Add-support-for-Validity-138a-0094-Lenovo-Yoga-910-IdeaPad.patch
│   └── libfprint-tod-vfs0090/
│       ├── 0001-Add-Validity-138a-0094-match-on-host-support.patch
│       ├── 0002-Treat-sensor-capture-failed-as-retry.patch
│       └── 0003-Auto-initialize-features-for-modern-libfprint.patch
├── tools/
│   ├── setup-pairing-env.sh      # Clones python-validity, applies patches, pulls firmware
│   ├── fetch-firmware.sh         # Extracts 6_07f_Lenovo.xpfwext from Lenovo package
│   └── pair-sensor.py            # Flash partitioning, crypto init, and sensor calibration
├── build/
│   └── Containerfile.builder     # Podman/Docker build recipe for libfprint
└── udev/
    ├── 60-libfprint-2-vfs0090.rules
    └── 99-validity-0094-no-autosuspend.rules
```

---

## Pairing (One-Time)

Writes the partition table and Lenovo extension firmware to sensor SPI flash. Required once per machine; survives OS reinstalls.

```bash
# 1. Fetch firmware and prepare local python-validity tree
./tools/setup-pairing-env.sh

# 2. Initialize and calibrate sensor flash
sudo /tmp/venv-validity/bin/python3 ./tools/pair-sensor.py \
    --python-validity ./build/python-validity \
    --factory-reset
```

Expected output:
```
Flash has 5 partitions.
Detected firmware version 1.0 (Tue Nov  8 02:05:20 2016)
Opening sensor: VSI 55E FM187-001
Creating a new user storage object
SENSOR-OPEN-OK
The sensor is paired and opens.
```

---

## Building

Build `libfprint` with in-tree `vfs0090` using Podman. The library links the
shared libraries of the Fedora release it is built on (OpenSSL 3 on Fedora 44,
OpenSSL 4 on Fedora 45), so build one per release and use the matching one:

```bash
podman build --build-arg FEDORA=45 --target artifacts --output ./build -f build/Containerfile.builder .
```

Releases carry `validity-0094-fedora44-x86_64.tar.gz` and
`validity-0094-fedora45-x86_64.tar.gz`, with `SHA256SUMS`.

---

## Installation
```bash
# Automatic install (detects distro library path, installs udev rules, restarts fprintd):
sudo ./tools/install.sh
```

Or manual install:
- **Fedora / RHEL**:
  ```bash
  sudo cp ./build/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
  sudo cp ./udev/*.rules /usr/lib/udev/rules.d/
  sudo udevadm control --reload && sudo udevadm trigger
  sudo systemctl restart fprintd
  ```
- **Debian / Ubuntu**:
  ```bash
  sudo cp ./build/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
  sudo cp ./udev/*.rules /lib/udev/rules.d/
  sudo udevadm control --reload && sudo udevadm trigger
  sudo systemctl restart fprintd
  ```

### PAM Configuration
- Fedora:
  ```bash
  sudo authselect enable-feature with-fingerprint
  sudo authselect apply-changes
  ```
- Ubuntu / Debian:
  ```bash
  sudo pam-auth-update --enable fprintd
  ```

---

## Verification

Test enrollment and verification using `libfprint` example binaries:

```bash
# Enroll right index finger
sudo LD_LIBRARY_PATH=./build ./examples/enroll

# Verify live print against stored template
sudo LD_LIBRARY_PATH=./build ./examples/verify
```

Verification log:
```
(process:61295): libfprint-vfs009x-DEBUG: Got image of 144x144, 8 bit per pixel
(process:61295): libfprint-vfs009x-DEBUG: Detecting minutiae
(process:61295): libfprint-print-DEBUG: score 26/12
(process:61295): libfprint-vfs009x-DEBUG: Verified finger 0 minutiae: match
(process:61295): libfprint-device-DEBUG: Device reported verify result (result: FPI_MATCH_SUCCESS)
MATCH!
```

---

## Upstream References

- Flash layout and signature fix: [uunicorn/python-validity#72](https://github.com/uunicorn/python-validity/issues/72)
- Driver base: [3v1n0/libfprint-tod-vfs0090](https://github.com/3v1n0/libfprint-tod-vfs0090)

---

## Credits

- Régis Leloup ([@Neonunux](https://github.com/Neonunux)): 0094 empty signature discovery and flash layout.
- Marco Trevisan ([@3v1n0](https://github.com/3v1n0)): `libfprint-tod-vfs0090` driver.
- Nikita Mikhailov ([@nmikhailov](https://github.com/nmikhailov)): `Validity90` protocol reverse engineering.
- [@uunicorn](https://github.com/uunicorn): `python-validity` stack.
