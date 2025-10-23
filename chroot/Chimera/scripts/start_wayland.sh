#!/bin/sh
set -e
echo "=== Starting Wayland ==="

# Environment setup
export LIBHYBRIS_LD_LIBRARY_PATH=/system/lib64:/vendor/lib64
export LD_LIBRARY_PATH=/usr/lib/libhybris:/usr/lib:$LD_LIBRARY_PATH
export XDG_RUNTIME_DIR=/tmp/wayland-runtime
export GBM_BACKEND=mali
export EGL_PLATFORM=wayland

mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Create wayland user
if ! id wayland >/dev/null 2>&1; then
    adduser -D wayland
    for group in video input render graphics; do
        addgroup wayland $group 2>/dev/null || true
    done
fi

# Start seatd
if command -v seatd >/dev/null; then
    seatd -g video > /tmp/seatd.log 2>&1 &
    sleep 2
fi

# Start Weston
if command -v weston >/dev/null; then
    echo "Starting Weston compositor..."
    weston --backend=drm-backend.so --log=/tmp/weston.log > /dev/null 2>&1 &
    WESTON_PID=$!
    
    sleep 3
    if kill -0 $WESTON_PID 2>/dev/null; then
        echo "✓ Weston started (PID: $WESTON_PID)"
        echo "Touch the screen to test!"
        wait $WESTON_PID
    else
        echo "Weston failed - check /tmp/weston.log"
    fi
else
    echo "Weston not available"
fi
