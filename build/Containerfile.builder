# Multi-stage Containerfile to build patched libfprint for Fedora
FROM registry.fedoraproject.org/fedora:44 AS builder

RUN dnf install -y --setopt=install_weak_deps=False \
    meson ninja-build gcc gcc-c++ git glib2-devel libgudev-devel libgusb-devel \
    pixman-devel nss-devel openssl-devel systemd-devel libudev-devel \
    gobject-introspection-devel cmake

WORKDIR /build

# Clone base libfprint with vfs009x driver wiring
RUN git clone --depth 1 -b vfs009x https://gitlab.archlinux.org/gugah/libfprint.git /build

# Apply our modern meson fix and vfs0090 patches
COPY patches/libfprint-tod-vfs0090/ /tmp/patches/
RUN git -C /build apply /tmp/patches/*.patch || true && \
    sed -i 's/foreach driver_test: drivers_tests/foreach driver_test, test_args : drivers_tests/' /build/tests/meson.build

# Configure and compile in-tree driver
RUN meson setup _build \
    --prefix=/usr \
    --libdir=lib64 \
    -Ddoc=false \
    -Dintrospection=false \
    -Dudev_rules=disabled \
    -Dudev_hwdb=disabled \
    -Ddrivers=vfs0090 && \
    ninja -C _build

# Output stage
FROM scratch AS artifacts
COPY --from=builder /build/_build/libfprint/libfprint-2.so.2.0.0 /
