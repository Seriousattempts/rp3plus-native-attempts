#!/sbin/sh
#
# UMS512 Install Ubuntu Image to Partition 77
# Installs ubuntu.img from SD card to /dev/block/mmcblk0p77
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
UBUNTU_IMG="${SD_CARD}/ubuntu.img"
MOUNT_POINT="/tmp/p77_mount"

echo "========================================"
echo "UMS512 Ubuntu Installation Script"
echo "Install ubuntu.img to mmcblk0p77/data"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Mount the partition"
echo "3. Create /data directory"
echo "4. Extract ubuntu.img contents to /data"
sleep 5

echo ""
echo "[1/10] Checking if ubuntu.img exists..."
if [ ! -f "$UBUNTU_IMG" ]; then
    echo "ERROR: $UBUNTU_IMG not found!"
    echo "Please ensure ubuntu.img is on your SD card at: $SD_CARD"
    echo ""
    echo "Available files in $SD_CARD:"
    ls -lh "$SD_CARD"/*.img 2>/dev/null || echo "No .img files found"
    exit 1
fi
echo "✓ Found ubuntu.img at $UBUNTU_IMG"
IMG_SIZE=$(ls -lh "$UBUNTU_IMG" | awk '{print $5}')
echo "  Size: $IMG_SIZE"

echo ""
echo "[2/10] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    exit 1
fi
echo "✓ Partition 77 exists: ${DEVICE}p${PARTITION_77}"

echo ""
echo "[3/10] Checking required tools..."
MISSING_TOOLS=""

if ! command -v mke2fs &> /dev/null; then
    MISSING_TOOLS="${MISSING_TOOLS}mke2fs "
fi

if ! command -v mount &> /dev/null; then
    MISSING_TOOLS="${MISSING_TOOLS}mount "
fi

if [ -n "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools: $MISSING_TOOLS"
    exit 1
fi
echo "✓ All required tools available"

# Check for progress tools
if command -v rsync &> /dev/null; then
    COPY_METHOD="rsync"
    echo "✓ rsync available - will use with progress display"
elif command -v pv &> /dev/null; then
    COPY_METHOD="pv"
    echo "✓ pv available - will use with progress display"
else
    COPY_METHOD="cp"
    echo "⚠ Using basic cp - limited progress information"
fi

echo ""
echo "[4/10] Unmounting partition 77 if mounted..."
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    echo "Unmounting ${DEVICE}p${PARTITION_77}..."
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        echo "ERROR: Could not unmount ${DEVICE}p${PARTITION_77}"
        exit 1
    fi
fi
echo "✓ Partition 77 is not mounted"

echo ""
echo "[5/10] Getting partition size..."
PARTITION_SIZE=$(cat /proc/partitions | grep "mmcblk0p${PARTITION_77}" | awk '{print $3}')
if [ -z "$PARTITION_SIZE" ]; then
    echo "ERROR: Could not determine partition size"
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

echo ""
echo "[6/10] Formatting partition 77 as ext4..."
echo "Wiping partition header..."
dd if=/dev/zero of=${DEVICE}p${PARTITION_77} bs=1M count=1 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Could not wipe partition header"
    exit 1
fi

echo "Creating ext4 filesystem..."
mke2fs -F -t ext4 -b 4096 -L linuxdata ${DEVICE}p${PARTITION_77}
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create ext4 filesystem"
    echo "Trying alternative method..."
    mkfs.ext4 -F ${DEVICE}p${PARTITION_77}
    if [ $? -ne 0 ]; then
        echo "ERROR: Alternative format method also failed"
        exit 1
    fi
fi
echo "✓ ext4 filesystem created successfully"

sync
sleep 2

echo ""
echo "[7/10] Mounting partition 77..."
mkdir -p "$MOUNT_POINT" 2>/dev/null

mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    echo "Partition info:"
    blkid ${DEVICE}p${PARTITION_77}
    exit 1
fi
echo "✓ Partition 77 mounted at $MOUNT_POINT"

echo ""
echo "[8/10] Creating /data directory..."
mkdir -p "${MOUNT_POINT}/data"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not create /data directory"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ /data directory created"

echo ""
echo "[9/10] Installing ubuntu.img to /data..."
echo "This may take several minutes depending on image size..."
echo "Copy method: $COPY_METHOD"
echo ""

# Mount ubuntu.img
UBUNTU_MOUNT="/tmp/ubuntu_mount"
mkdir -p "$UBUNTU_MOUNT" 2>/dev/null

echo "Mounting ubuntu.img..."
mount -t ext4 -o loop "$UBUNTU_IMG" "$UBUNTU_MOUNT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount ubuntu.img"
    echo "Image info:"
    file "$UBUNTU_IMG" 2>/dev/null || echo "Cannot determine file type"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ ubuntu.img mounted"
echo ""

# Count total files for progress tracking
echo "Counting files in ubuntu.img..."
TOTAL_FILES=$(find "$UBUNTU_MOUNT" -type f | wc -l)
echo "Total files to copy: $TOTAL_FILES"
echo ""

echo "Starting copy operation..."
echo "============================================"

# Use appropriate copy method
case "$COPY_METHOD" in
    rsync)
        # Best option - shows detailed progress
        rsync -ah --info=progress2 "$UBUNTU_MOUNT/" "${MOUNT_POINT}/data/"
        COPY_RESULT=$?
        ;;
    
    pv)
        # Good option - shows transfer rate
        tar -cf - -C "$UBUNTU_MOUNT" . | pv -s $(du -sb "$UBUNTU_MOUNT" | awk '{print $1}') | tar -xf - -C "${MOUNT_POINT}/data"
        COPY_RESULT=$?
        ;;
    
    cp)
        # Fallback - show periodic updates
        echo "Copying files (periodic updates every 10 seconds)..."
        COPIED=0
        
        # Run cp in background
        cp -a "$UBUNTU_MOUNT/"* "${MOUNT_POINT}/data/" &
        CP_PID=$!
        
        # Monitor progress
        while kill -0 $CP_PID 2>/dev/null; do
            sleep 10
            CURRENT_FILES=$(find "${MOUNT_POINT}/data" -type f 2>/dev/null | wc -l)
            CURRENT_SIZE=$(du -sh "${MOUNT_POINT}/data" 2>/dev/null | awk '{print $1}')
            PERCENT=$((CURRENT_FILES * 100 / TOTAL_FILES))
            echo "Progress: $CURRENT_FILES/$TOTAL_FILES files ($PERCENT%) - Size: $CURRENT_SIZE"
        done
        
        wait $CP_PID
        COPY_RESULT=$?
        ;;
esac

echo "============================================"
echo ""

if [ $COPY_RESULT -ne 0 ]; then
    echo "WARNING: Copy operation reported errors (exit code: $COPY_RESULT)"
    echo "Some files may not have copied correctly"
else
    echo "✓ Copy operation completed successfully"
fi

echo ""
echo "Unmounting ubuntu.img..."
umount "$UBUNTU_MOUNT"
rmdir "$UBUNTU_MOUNT" 2>/dev/null

echo ""
echo "[10/10] Final verification..."
echo "Checking /data contents:"
ls -la "${MOUNT_POINT}/data" | head -15
echo ""
echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""
echo "File count verification:"
FINAL_FILES=$(find "${MOUNT_POINT}/data" -type f 2>/dev/null | wc -l)
echo "Files copied: $FINAL_FILES / $TOTAL_FILES"

sync
sleep 2

echo ""
echo "Unmounting partition 77..."
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "WARNING: Could not unmount partition 77 cleanly"
    umount -f "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT" 2>/dev/null

echo ""
echo "========================================"
echo "✓ UBUNTU INSTALLATION COMPLETED"
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition: ${DEVICE}p77"
echo "- Filesystem: ext4"
echo "- Ubuntu installed to: /data"
echo "- Files copied: $FINAL_FILES"
echo ""
