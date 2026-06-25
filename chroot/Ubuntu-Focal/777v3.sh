#!/sbin/sh
#
# UMS512 
# Install focal rootfs & APEX to Partition 77
# From SD card to /dev/block/mmcblk0p77

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
FOCAL="${SD_CARD}/focaltu-arm64.tar.gz"
ANDROID_IMG="${SD_CARD}/android-rootfs.img"
MOUNT_POINT="/tmp/p77_mount"
ANDROID_MOUNT="/tmp/android_mount"

# File count trackers
ROOTFS_TOTAL_FILES=0
FINAL_APEX_FILES=0
TOTAL_PARTITION_FILES=0

echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Extract $FOCAL to partition root"
echo "3. Copy /system/apex from $ANDROID_IMG to partition root"
sleep 5

echo ""
echo "[1/10] Checking if required files exist..."
if [ ! -f "$FOCAL" ]; then
    echo "ERROR: $FOCAL not found!"
    exit 1
fi
echo "✓ Found archive at $FOCAL"

if [ ! -f "$ANDROID_IMG" ]; then
    echo "ERROR: $ANDROID_IMG not found!"
    echo "Please ensure android-rootfs.img is on your SD card."
    exit 1
fi
echo "✓ Found Android image at $ANDROID_IMG"

echo ""
echo "[2/10] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    exit 1
fi
echo "✓ Partition 77 exists: ${DEVICE}p${PARTITION_77}"

echo ""
echo "[3/10] Checking required tools..."
MISSING_TOOLS=""

for tool in mke2fs mount tar cp; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="${MISSING_TOOLS}$tool "
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools: $MISSING_TOOLS"
    exit 1
fi
echo "✓ All required tools available"

echo ""
echo "[4/10] Unmounting partition 77 if mounted..."
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
fi
echo "✓ Partition 77 is not mounted"

echo ""
echo "[5/10] Getting partition size..."
PARTITION_SIZE=$(cat /proc/partitions | grep "mmcblk0p${PARTITION_77}" | awk '{print $3}')
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

echo ""
echo "[6/10] Formatting partition 77 as ext4..."
echo "Wiping partition header..."
dd if=/dev/zero of=${DEVICE}p${PARTITION_77} bs=1M count=1 2>/dev/null

echo "Creating ext4 filesystem..."
mke2fs -F -t ext4 -b 4096 -L linuxdata ${DEVICE}p${PARTITION_77}
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create ext4 filesystem"
    exit 1
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
    exit 1
fi
echo "✓ Partition 77 mounted at $MOUNT_POINT"

echo ""
echo "[8/10] Extracting focal rootfs to partition..."
echo "This may take several minutes depending on archive size."
echo "============================================"

# Run tar extraction in the background to allow progress monitoring
tar -xpzf "$FOCAL" -C "$MOUNT_POINT" &
TAR_PID=$!

# Monitor progress while tar is running
while kill -0 $TAR_PID 2>/dev/null; do
    sleep 10
    CURRENT_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
    CURRENT_SIZE=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}')
    echo "Extracting... $CURRENT_FILES files written - Current Size: $CURRENT_SIZE"
done

# Wait for background job to finish and catch the exit code
wait $TAR_PID
EXTRACT_RESULT=$?

# Tally rootfs files immediately after tar completes
ROOTFS_TOTAL_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)

echo "============================================"
if [ $EXTRACT_RESULT -ne 0 ]; then
    echo "WARNING: Extraction operation reported errors (exit code: $EXTRACT_RESULT)"
    echo "Files extracted so far: $ROOTFS_TOTAL_FILES"
else
    echo "✓ Extraction completed successfully. Total rootfs files: $ROOTFS_TOTAL_FILES"
fi

echo ""
echo "[9/10] Extracting /system/apex from android-rootfs.img..."
mkdir -p "$ANDROID_MOUNT" 2>/dev/null

echo "Mounting $ANDROID_IMG as loop device..."
mount -o ro,loop "$ANDROID_IMG" "$ANDROID_MOUNT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount android-rootfs.img."
    APEX_RESULT=1
else
    if [ -d "$ANDROID_MOUNT/system/apex" ]; then
        # Count total files in APEX for percentage math
        TOTAL_APEX_FILES=$(find "$ANDROID_MOUNT/system/apex" -type f 2>/dev/null | wc -l)
        echo "Found /system/apex. Total files to copy: $TOTAL_APEX_FILES"
        echo "Starting copy operation..."
        
        # Run copy in background
        cp -a "$ANDROID_MOUNT/system/apex" "${MOUNT_POINT}/" &
        CP_PID=$!
        
        # Monitor progress with percentage
        while kill -0 $CP_PID 2>/dev/null; do
            sleep 5
            CURRENT_APEX_FILES=$(find "${MOUNT_POINT}/apex" -type f 2>/dev/null | wc -l)
            if [ "$TOTAL_APEX_FILES" -gt 0 ]; then
                PERCENT=$((CURRENT_APEX_FILES * 100 / TOTAL_APEX_FILES))
                echo "Progress: $CURRENT_APEX_FILES/$TOTAL_APEX_FILES files ($PERCENT%)"
            fi
        done
        
        wait $CP_PID
        if [ $? -eq 0 ]; then
            FINAL_APEX_FILES=$(find "${MOUNT_POINT}/apex" -type f 2>/dev/null | wc -l)
            echo "✓ /apex directory copied successfully. Total APEX files: $FINAL_APEX_FILES"
            APEX_RESULT=0
        else
            echo "ERROR: Failed to copy /apex directory"
            APEX_RESULT=1
        fi
    else
        echo "ERROR: /system/apex directory not found inside the image!"
        APEX_RESULT=1
    fi
    
    echo "Unmounting $ANDROID_IMG..."
    umount "$ANDROID_MOUNT"
    rmdir "$ANDROID_MOUNT" 2>/dev/null
fi

echo ""
echo "[10/10] Final verification..."
echo "Checking root contents:"
ls -la "${MOUNT_POINT}" | head -20
echo ""

# Tally the absolute total amount of files on the partition before unmounting
TOTAL_PARTITION_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)

# Verify critical directories including the newly added apex
echo "Verifying directory structure..."
ALL_DIRS_EXIST=true
for dir in apex etc bin usr var home root; do
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
    umount -f "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT" 2>/dev/null

echo ""
echo "========================================"
if [ "$ALL_DIRS_EXIST" = true ] && [ $EXTRACT_RESULT -eq 0 ] && [ $APEX_RESULT -eq 0 ]; then
    echo "✓ INSTALLATION COMPLETED SUCCESSFULLY"
else
    echo "⚠ INSTALLATION COMPLETED WITH WARNINGS/ERRORS"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition: ${DEVICE}p77"
echo "- Focal rootfs files extracted: $ROOTFS_TOTAL_FILES"
echo "- APEX files copied: $FINAL_APEX_FILES"
echo "- Total files on partition: $TOTAL_PARTITION_FILES"
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