#!/system/bin/sh
# Ubuntu Desktop in TWRP with full hardware access

INSTALL_PATH="/external_sd/3PLUSLINUX"
LOG="$INSTALL_PATH/boot.log"

exec > "$LOG" 2>&1

echo "=== Ubuntu Desktop Boot - $(date) ==="

if [ ! -d "$INSTALL_PATH/ubuntu-fs" ]; then
    echo "ERROR: Ubuntu not found at $INSTALL_PATH"
    exit 1
fi

cd "$INSTALL_PATH" || exit 1

# Mount Android system partitions (read-only for driver access)
echo "Mounting Android partitions..."
mkdir -p ubuntu-fs/android/system ubuntu-fs/android/vendor
mount -o ro /system ubuntu-fs/android/system 2>/dev/null
mount -o ro /vendor ubuntu-fs/android/vendor 2>/dev/null

# Create essential directories
echo "Creating filesystem structure..."
mkdir -p ubuntu-fs/dev
mkdir -p ubuntu-fs/dev/pts
mkdir -p ubuntu-fs/proc
mkdir -p ubuntu-fs/sys
mkdir -p ubuntu-fs/tmp

# Method 1: Bind mount /dev (gives real-time access to ALL device nodes)
echo "Bind mounting /dev for complete hardware access..."
mount --bind /dev ubuntu-fs/dev

# Method 2: If bind mount fails, copy all device nodes individually
if [ $? -ne 0 ]; then
    echo "Bind mount failed, copying device nodes individually..."
    
    DEV_COUNT=0
    DEV_SUCCESS=0
    DEV_FAILED=0
    
    # Find all character and block devices
    for dev_node in $(find /dev -maxdepth 2 -type c -o -type b 2>/dev/null); do
        DEV_COUNT=$((DEV_COUNT + 1))
        dev_name=$(basename "$dev_node")
        
        if cp -a "$dev_node" "ubuntu-fs/dev/$dev_name" 2>/dev/null; then
            DEV_SUCCESS=$((DEV_SUCCESS + 1))
        else
            DEV_FAILED=$((DEV_FAILED + 1))
        fi
    done
    
    echo "Device nodes copied: $DEV_SUCCESS/$DEV_COUNT (failed: $DEV_FAILED)"
    
    # Ensure critical device nodes exist
    [ ! -e ubuntu-fs/dev/null ] && mknod -m 666 ubuntu-fs/dev/null c 1 3
    [ ! -e ubuntu-fs/dev/zero ] && mknod -m 666 ubuntu-fs/dev/zero c 1 5
    [ ! -e ubuntu-fs/dev/random ] && mknod -m 666 ubuntu-fs/dev/random c 1 8
    [ ! -e ubuntu-fs/dev/urandom ] && mknod -m 666 ubuntu-fs/dev/urandom c 1 9
fi

# Bind mount kernel filesystems
echo "Mounting kernel filesystems..."
mount -t proc proc ubuntu-fs/proc
mount -t sysfs sysfs ubuntu-fs/sys
mount -t devpts devpts ubuntu-fs/dev/pts

# Set permissions for graphics (if not already writable)
chmod 666 ubuntu-fs/dev/dri/card0 2>/dev/null
chmod 666 ubuntu-fs/dev/null ubuntu-fs/dev/zero ubuntu-fs/dev/full 2>/dev/null

# Create XDG runtime directory for Weston
mkdir -p ubuntu-fs/tmp/runtime-root
chmod 700 ubuntu-fs/tmp/runtime-root

# Verify critical hardware access
echo ""
echo "Hardware access configured:"
echo "Graphics: $(ls -l ubuntu-fs/dev/dri/card0 2>/dev/null || echo 'NOT FOUND')"
echo "Input devices: $(ls ubuntu-fs/dev/input/ 2>/dev/null | wc -l) devices"
echo "Sound devices: $(ls ubuntu-fs/dev/snd/ 2>/dev/null | wc -l) devices"
echo "Total /dev nodes: $(ls ubuntu-fs/dev/ 2>/dev/null | wc -l)"
echo ""

echo "Entering Ubuntu..."
echo "==========================================="
echo "Type 'weston --backend=drm-backend.so --tty=1' to start desktop"
echo "==========================================="

# Launch Ubuntu with full environment
chroot ubuntu-fs /usr/bin/env -i \
    HOME=/root \
    USER=root \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/android/system/bin:/android/vendor/bin \
    LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/android/system/lib64:/android/vendor/lib64 \
    LANG=C.UTF-8 \
    /bin/bash --login

# Cleanup
echo "Cleaning up..."
umount ubuntu-fs/dev/pts 2>/dev/null
umount ubuntu-fs/dev 2>/dev/null
umount ubuntu-fs/proc 2>/dev/null
umount ubuntu-fs/sys 2>/dev/null
umount ubuntu-fs/android/system 2>/dev/null
umount ubuntu-fs/android/vendor 2>/dev/null

echo "=== Session ended - $(date) ==="
