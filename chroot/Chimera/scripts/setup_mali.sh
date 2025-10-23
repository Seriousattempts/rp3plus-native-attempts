#!/bin/sh
set -e
echo "=== Setting up Mali G52 drivers ==="

mkdir -p /system/lib64/{egl,hw}
mkdir -p /vendor/lib64

# Copy drivers
cp /mnt/sdcard/mali-drivers/libGLES_mali.so /system/lib64/ 2>/dev/null || echo "libGLES_mali.so not found"
cp /mnt/sdcard/mali-drivers/gralloc.default.so /system/lib64/hw/ 2>/dev/null || echo "gralloc.default.so not found"
cp /mnt/sdcard/mali-drivers/*.so /system/lib64/hw/ 2>/dev/null || true

# EGL config
cat > /system/lib64/egl/egl.cfg << 'EOL'
0 0 android
0 1 mali
EOL

# libhybris paths
cat > /etc/ld.so.conf.d/hybris.conf << 'EOL'
/usr/lib/libhybris
/system/lib64
/system/lib64/egl
/system/lib64/hw
/vendor/lib64
EOL

ldconfig
echo "✓ Mali driver setup complete"
