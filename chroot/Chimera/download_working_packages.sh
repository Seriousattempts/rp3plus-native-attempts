#!/bin/bash
set -e

echo "=== Downloading VERIFIED working packages ==="

# These URLs have been tested and work
EDGE_MAIN="https://dl-cdn.alpinelinux.org/alpine/edge/main/aarch64"
EDGE_COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/edge/community/aarch64"
STABLE="https://dl-cdn.alpinelinux.org/alpine/v3.20/main/aarch64"
STABLE_COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/v3.20/community/aarch64"

mkdir -p packages/main

echo "=== Core System (Working) ==="
wget $EDGE_MAIN/alpine-baselayout-3.7.1-r1.apk -P packages/main/
wget $EDGE_MAIN/alpine-keys-2.6-r0.apk -P packages/main/
wget $EDGE_MAIN/busybox-1.37.0-r23.apk -P packages/main/
wget $EDGE_MAIN/apk-tools-3.0.0_rc5_git20250819-r0.apk -P packages/main/
wget $EDGE_MAIN/musl-1.2.5-r20.apk -P packages/main/

echo "=== Graphics Stack (Working) ==="
wget $EDGE_MAIN/libdrm-2.4.126-r0.apk -P packages/main/
wget $EDGE_MAIN/mesa-25.2.4-r0.apk -P packages/main/
wget $EDGE_MAIN/mesa-dri-gallium-25.2.4-r0.apk -P packages/main/
wget $EDGE_MAIN/mesa-gbm-25.2.4-r0.apk -P packages/main/
wget $EDGE_MAIN/mesa-egl-25.2.4-r0.apk -P packages/main/
wget $EDGE_MAIN/mesa-gles-25.2.4-r0.apk -P packages/main/

echo "=== Wayland Compositor (Working) ==="
wget $EDGE_COMMUNITY/weston-14.0.2-r3.apk -P packages/main/

echo "=== System Libraries (Working) ==="
wget $EDGE_MAIN/eudev-3.2.14-r5.apk -P packages/main/
wget $EDGE_MAIN/zlib-1.3.1-r2.apk -P packages/main/

echo "=== Additional Working Packages ==="
wget $STABLE/wayland-libs-server-1.22.0-r4.apk -P packages/main/
wget $STABLE/wayland-libs-client-1.22.0-r4.apk -P packages/main/
wget $STABLE/dbus-1.14.10-r1.apk -P packages/main/
wget $STABLE/readline-8.2.10-r0.apk -P packages/main/
wget $STABLE/libffi-3.4.6-r0.apk -P packages/main/
wget $STABLE/gcompat-1.1.0-r4.apk -P packages/main/
wget $STABLE/linux-pam-1.6.0-r0.apk -P packages/main/
wget $STABLE_COMMUNITY/seatd-0.8.0-r0.apk -P packages/main/

echo "=== libhybris Source ==="
wget https://github.com/libhybris/libhybris/archive/refs/heads/master.zip -O packages/main/libhybris-source.zip

echo "=== Download Complete ==="
downloaded=$(ls -1 packages/main/*.apk 2>/dev/null | wc -l)
echo "Downloaded $downloaded packages successfully!"
