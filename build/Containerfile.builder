# Multi-stage Containerfile to build patched libfprint for a Fedora release
# (podman build --build-arg FEDORA=45 ...); the library links that release's OpenSSL.
ARG FEDORA=44
FROM registry.fedoraproject.org/fedora:${FEDORA} AS builder

RUN dnf install -y --setopt=install_weak_deps=False \
    meson ninja-build gcc gcc-c++ git glib2-devel libgudev-devel libgusb-devel \
    pixman-devel nss-devel openssl-devel systemd-devel libudev-devel \
    gobject-introspection-devel cmake

WORKDIR /build

# Clone base libfprint and its vfs0090 submodule
RUN git clone --depth 1 -b vfs009x https://gitlab.archlinux.org/gugah/libfprint.git /build && \
    git clone https://github.com/3v1n0/libfprint-tod-vfs0090.git /build/libfprint/drivers/vfs0090 && \
    cd /build/libfprint/drivers/vfs0090 && \
    git checkout 252c98495791839b36fe5154f55ecca62df2e76a

# Apply our vfs0090 patches (0094 support, retry handling, modern features init)
COPY patches/libfprint-tod-vfs0090/ /tmp/patches/
RUN cd /build/libfprint/drivers/vfs0090 && \
    git apply /tmp/patches/*.patch && \
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
