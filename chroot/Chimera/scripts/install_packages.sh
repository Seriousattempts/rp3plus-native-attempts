#!/bin/sh
set -e
echo "=== Installing Alpine packages ==="
cd /mnt/sdcard/packages/main

for pkg in *.apk; do
    [ "$pkg" = "*.apk" ] && continue
    echo "Installing: $pkg"
    apk add --allow-untrusted --no-network "$pkg" 2>/dev/null || echo "Failed: $pkg"
done

echo "✓ Package installation complete"
