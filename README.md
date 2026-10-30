# Validity Sensors 138a:0094 Linux Driver & Pairing

Linux support, patches, and pairing tooling for the **Validity Sensors, Inc. 138a:0094** fingerprint reader (found on Lenovo IdeaPad FLEX 4, Yoga 910/720, and IdeaPad Air 13 Pro).

This project unlocks **100% native Linux biometrics** using open-source code and official Lenovo microcode extensions, without requiring Windows DLLs or proprietary daemon wrappers.

---

## Hardware Overview

| Attribute | Specification |
| :--- | :--- |
| **USB ID** | `138a:0094` |
| **Vendor** | Validity Sensors, Inc. (Synaptics) |
| **Model** | VFS7552 / Prometheus Family |
| **ROM Version** | `v6.7 (build 164)` |
| **Architecture** | **Match-on-Host** (144×144 raw 8bpp capture, minutiae matched via Bozorth3 on host) |
| **Twin Hardware** | Architectural twin of ThinkPad `138a:0090`, sharing the same ROM and firmware blob (`6_07f_Lenovo.xpfwext`) |

---

## Technical Breakthroughs

Past attempts to reverse-engineer `138a:0094` failed with sensor rejection error `0x04af`. Three key breakthroughs solved it:

1. **Unsigned Partition Table (Crucial):**
   - The ThinkPad `0090` requires an RSA signature appended to the partition table during flash initialization.
   - The `0094` rejects any appended RSA signature with error `0x04af`. It requires an **empty partition signature** (`signature = b''`). The device validates only the SHA-256 hashes of the 5 partition entries.
2. **Flash Memory Layout:**
   - The template database size in flash is `0xb0000` (compared to `0x30000` on 0090).
3. **Modern Libfprint Feature Initialization (`libfprint >= 1.94`):**
   - Modern `libfprint` enforces `g_assert(cls->features != FP_DEVICE_FEATURE_NONE)` during object construction.
   - Calling `fpi_device_class_auto_initialize_features(dev_class)` in `fpi_device_vfs0090_class_init` dynamically populates the feature bitmask from registered driver callbacks (`enroll`, `verify`, `identify`, `capture`).

---

## Repository Structure

```
├── patches/
│   ├── python-validity/
│   │   └── 0001-Add-support-for-Validity-138a-0094-Lenovo-Yoga-910-IdeaPad.patch
│   └── libfprint-tod-vfs0090/
│       ├── 0001-Add-Validity-138a-0094-match-on-host-support.patch
│       ├── 0002-Treat-sensor-capture-failed-as-retry.patch
│       └── 0003-Auto-initialize-features-for-modern-libfprint.patch
├── tools/
│   ├── setup-pairing-env.sh      # Automated helper to fetch firmware and prepare python-validity
│   ├── fetch-firmware.sh         # Downloads official ThinkPad driver & extracts 6_07f_Lenovo.xpfwext
│   └── pair-sensor.py            # One-time pairing, flash partitioning, and sensor calibration
├── build/
│   └── Containerfile.builder     # Reproducible container build for Fedora libfprint
└── udev/
    ├── 60-libfprint-2-vfs0090.rules
    └── 99-validity-0094-no-autosuspend.rules
```

---

## Step 1: One-Time Hardware Pairing & Calibration

> **Important:** Pairing writes the partition table, cryptographic keys, and Lenovo extension firmware into the physical chip's onboard SPI flash. **This only needs to be run once per laptop.** Once paired, the hardware retains its pairing permanently across OS reinstalls and updates.

### 1. Set up the pairing environment:
```bash
./tools/setup-pairing-env.sh
```

### 2. Run the pairing tool:
```bash
sudo /tmp/venv-validity/bin/python3 ./tools/pair-sensor.py \
    --python-validity ./build/python-validity \
    --factory-reset
```

Expected output:
```
Flash has 5 partitions.
Detected firmware version 1.0 (Tue Nov  8 02:05:20 2016)
Opening sensor: VSI 55E FM187-001
No calibration data was loaded. Calibrating...
Creating a new user storage object
SENSOR-OPEN-OK
The sensor is paired and opens.
```

---

## Step 2: Compiling the Driver

Use the container builder to compile the patched `libfprint-2.so.2.0.0` without installing toolchains on your host:

```bash
podman build -t fprint-0094 -f build/Containerfile.builder .
podman cp $(podman create fprint-0094):/libfprint-2.so.2.0.0 ./build/libfprint-2.so.2.0.0
```

---

## Step 3: System Installation

### Fedora / RHEL:
```bash
# Install the library
sudo cp ./build/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0

# Install udev rules
sudo cp ./udev/*.rules /usr/lib/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger

# Restart fprintd
sudo systemctl restart fprintd
```

### Debian / Ubuntu:
```bash
sudo cp ./build/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo cp ./udev/*.rules /lib/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
sudo systemctl restart fprintd
```

---

## Step 4: Enrolling and Enabling PAM Authentication

Once installed, use standard desktop tools or CLI:

```bash
# Enroll your finger (e.g. right index)
fprintd-enroll -f right-index-finger

# Verify match
fprintd-verify -f right-index-finger
```

### Enable fingerprint for login & sudo:
- **Fedora:**
  ```bash
  sudo authselect enable-feature with-fingerprint
  sudo authselect apply-changes
  ```
- **Ubuntu / Debian:**
  ```bash
  sudo pam-auth-update --enable fprintd
  ```

---

## Verification & Test Results

Tested and verified on Lenovo IdeaPad FLEX 4-1480 (Intel Core i5-7200U, Fedora Linux 44):

```
(process:60868): libfprint-vfs009x-DEBUG: Got image of 144x144, 8 bit per pixel
(process:60868): libfprint-vfs009x-DEBUG: Detecting minutiae
(process:60868): libfprint-image-DEBUG: Minutiae scan completed in 0.029792 secs
Enroll stage 5 of 5 passed. Yay!
Print for finger FP_FINGER_RIGHT_INDEX enrolled

(process:61295): libfprint-print-DEBUG: score 26/12
(process:61295): libfprint-vfs009x-DEBUG: Verified finger 0 minutiae: match
(process:61295): libfprint-device-DEBUG: Device reported verify result (result: FPI_MATCH_SUCCESS)
MATCH!
```

---

## Upstream Contributions

This repository tracks upstream pull requests for:
1. **[uunicorn/python-validity#72](https://github.com/uunicorn/python-validity/issues/72):** Flash layout, signature bypass, and firmware metadata for `138a:0094`.
2. **[3v1n0/libfprint-tod-vfs0090](https://github.com/3v1n0/libfprint-tod-vfs0090):** Hardware match-on-host support, weak-match tolerance, retry handling, and `fpi_device_class_auto_initialize_features`.

---

## Acknowledgments & Prior Art

- **Régis Leloup ([@Neonunux](https://github.com/Neonunux)):** Discovered the empty partition signature (`b''`) and flash layout for 0094.
- **Marco Trevisan ([@3v1n0](https://github.com/3v1n0)):** Author of the `libfprint-tod-vfs0090` driver and Snap packaging.
- **Nikita Mikhailov ([@nmikhailov](https://github.com/nmikhailov)):** Original protocol reverse-engineering in `Validity90`.
- **[@uunicorn](https://github.com/uunicorn):** Creator of `python-validity` pairing and cryptographic primitives.
