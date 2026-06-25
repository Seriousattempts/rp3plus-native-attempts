#!/sbin/sh
#
# UMS512 Install FOCAL to Partition 77
# Extracts tar.gz from SD card to /dev/block/mmcblk0p77
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
FOCAL="${SD_CARD}/focaltu-arm64-kodi.tar.gz"
MOUNT_POINT="/tmp/p77_mount"

echo "========================================"
echo "UMS512 FOCAL API30 Installation Script"
echo "Install FOCAL to mmcblk0p77 via Tarball"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Mount the partition"
echo "3. Extract $FOCAL directly to partition root"
sleep 5

echo ""
echo "[1/9] Checking if FOCAL archive exists..."
if [ ! -f "$FOCAL" ]; then
    echo "ERROR: $FOCAL not found!"
    echo "Please ensure focaltu-arm64-kodi.tar.gz is on your SD card at: $SD_CARD"
    echo ""
    echo "Available archives in $SD_CARD:"
    ls -lh "$SD_CARD"/*.tar.gz 2>/dev/null || echo "No .tar.gz files found"
    exit 1
fi
echo "✓ Found archive at $FOCAL"
ARCHIVE_SIZE=$(ls -lh "$FOCAL" | awk '{print $5}')
echo "  Archive Size: $ARCHIVE_SIZE"

echo ""
echo "[2/9] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    exit 1
fi
echo "✓ Partition 77 exists: ${DEVICE}p${PARTITION_77}"

echo ""
echo "[3/9] Checking required tools..."
MISSING_TOOLS=""

for tool in mke2fs mount tar; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="${MISSING_TOOLS}$tool "
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools: $MISSING_TOOLS"
    exit 1
fi
echo "✓ All required tools available"

if command -v pv &> /dev/null; then
    EXTRACT_METHOD="pv"
    echo "✓ pv available - will display extraction progress"
else
    EXTRACT_METHOD="tar"
    echo "⚠ pv not found - extraction will not show a progress bar"
fi

echo ""
echo "[4/9] Unmounting partition 77 if mounted..."
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
echo "[5/9] Getting partition size..."
PARTITION_SIZE=$(cat /proc/partitions | grep "mmcblk0p${PARTITION_77}" | awk '{print $3}')
if [ -z "$PARTITION_SIZE" ]; then
    echo "ERROR: Could not determine partition size"
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

echo ""
echo "[6/9] Formatting partition 77 as ext4..."
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
echo "[7/9] Mounting partition 77..."
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
echo "[8/9] Extracting focal rootfs to partition..."
echo "This may take several minutes. Please do not interrupt..."
echo "============================================"

if [ "$EXTRACT_METHOD" = "pv" ]; then
    pv "$FOCAL" | tar -xpzf - -C "$MOUNT_POINT"
    EXTRACT_RESULT=$?
else
    echo "Extracting (no progress bar available, please wait)..."
    tar -xpzf "$FOCAL" -C "$MOUNT_POINT"
    EXTRACT_RESULT=$?
fi

echo "============================================"
echo ""

if [ $EXTRACT_RESULT -ne 0 ]; then
    echo "WARNING: Extraction operation reported errors (exit code: $EXTRACT_RESULT)"
    echo "The archive might be corrupted or ran out of space."
else
    echo "✓ Extraction completed successfully"
fi

echo ""
echo "[9/9] Final verification..."
echo "Checking Focal rootfs contents:"
ls -la "${MOUNT_POINT}" | head -15
echo ""
echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""

FINAL_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
echo "Total files extracted: $FINAL_FILES"

# Verify critical FOCAL directories
echo ""
echo "Verifying FOCAL directory structure..."
ALL_DIRS_EXIST=true
for dir in etc bin usr var home root; do
    if [ -d "${MOUNT_POINT}/$dir" ]; then
        echo "  ✓ /$dir exists"
    else
        echo "  ✗ /$dir MISSING"
        ALL_DIRS_EXIST=false
    fi
done

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
if [ "$ALL_DIRS_EXIST" = true ] && [ $EXTRACT_RESULT -eq 0 ]; then
    echo "✓ FOCAL INSTALLATION COMPLETED SUCCESSFULLY"
else
    echo "⚠ FOCAL INSTALLATION COMPLETED WITH WARNINGS"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition: ${DEVICE}p77"
echo "- Filesystem: ext4"
echo "- Archive used: fexbian-rootfs.tar.gz"
echo "- Files extracted: $FINAL_FILES"
echo ""
echo "You must now click the middle home button"
echo "Click Wipe"
echo "Click Format Data"
echo "type:"
echo "yes"
echo "Click the middle home button again"
echo "Click Wipe"
echo "Click Advanced Wipe"
echo "Select metadata, Data"
echo "Swipe to Wipe"
echo "Then either reboot to system or back to recovery"