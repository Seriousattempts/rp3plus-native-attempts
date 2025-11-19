#!/sbin/sh
#
# UMS512 Repackage AlpHybris Rootfs from Partition 77
# Creates alphybris-api30-rootfs-modified.img from partition 77 root
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
OUTPUT_IMG="${SD_CARD}/alphybris-api30-rootfs-modified.img"
MOUNT_POINT="/tmp/p77_mount"
IMG_MOUNT="/tmp/img_mount"

echo "========================================"
echo "UMS512 AlpHybris Rootfs Repackaging Script"
echo "Extract modified rootfs to new .img file"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Mount partition 77"
echo "2. Calculate required image size"
echo "3. Create new ext4 image file"
echo "4. Copy partition root contents to new image"
echo "5. Save to SD card as alphybris-api30-rootfs-modified.img"
sleep 5

echo ""
echo "[1/8] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    exit 1
fi
echo "✓ Partition 77 exists"

echo ""
echo "[2/8] Checking SD card write access..."
if [ ! -w "$SD_CARD" ]; then
    echo "ERROR: Cannot write to SD card at $SD_CARD"
    exit 1
fi
echo "✓ SD card is writable"

# Check available space on SD card
SD_FREE=$(df -k "$SD_CARD" | tail -1 | awk '{print $4}')
SD_FREE_MB=$((SD_FREE / 1024))
echo "Available space on SD card: ${SD_FREE_MB} MB"

echo ""
echo "[3/8] Mounting partition 77..."
mkdir -p "$MOUNT_POINT" 2>/dev/null

mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    exit 1
fi
echo "✓ Partition 77 mounted at $MOUNT_POINT"

echo ""
echo "[4/8] Verifying Alpine rootfs exists..."
if [ ! -d "${MOUNT_POINT}/etc" ] || [ ! -d "${MOUNT_POINT}/bin" ]; then
    echo "ERROR: Alpine rootfs not found on partition 77"
    echo "Contents of partition:"
    ls -la "${MOUNT_POINT}" | head -15
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ Alpine rootfs found"

echo ""
echo "[5/8] Calculating required image size..."
echo "Analyzing directory size (this may take a minute)..."

# Get actual used space in KB
USED_SPACE=$(du -sk "${MOUNT_POINT}" | awk '{print $1}')
USED_MB=$((USED_SPACE / 1024))
echo "Rootfs size: ${USED_MB} MB"

# Add 20% overhead for ext4 metadata + 500MB buffer
OVERHEAD_MB=$((USED_MB * 20 / 100))
IMG_SIZE_MB=$((USED_MB + OVERHEAD_MB + 500))

echo "Calculated image size: ${IMG_SIZE_MB} MB (with overhead)"

# Check if we have enough space on SD card
if [ $IMG_SIZE_MB -gt $SD_FREE_MB ]; then
    echo "ERROR: Not enough space on SD card"
    echo "Required: ${IMG_SIZE_MB} MB"
    echo "Available: ${SD_FREE_MB} MB"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ Sufficient space available"

echo ""
echo "[6/8] Creating new ext4 image file..."
echo "Size: ${IMG_SIZE_MB} MB"
echo "This will take a few minutes..."

# Remove old image if exists
if [ -f "$OUTPUT_IMG" ]; then
    echo "Removing existing image..."
    rm -f "$OUTPUT_IMG"
fi

# Create empty file with dd
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=$IMG_SIZE_MB 2>&1 | \
    grep -E "(copied|records)" || echo "Creating image file..."

if [ ! -f "$OUTPUT_IMG" ]; then
    echo "ERROR: Failed to create image file"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ Image file created ($(ls -lh "$OUTPUT_IMG" | awk '{print $5}'))"

# Format as ext4
echo "Formatting image as ext4..."
mke2fs -F -t ext4 -b 4096 -L alphybris "$OUTPUT_IMG" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to format image"
    rm -f "$OUTPUT_IMG"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ Image formatted as ext4"

sync
sleep 2

echo ""
echo "[7/8] Copying Alpine rootfs to new image..."
echo "This may take 10-20 minutes depending on size..."
echo ""

# Create and mount the new image
mkdir -p "$IMG_MOUNT" 2>/dev/null
mount -t ext4 -o loop "$OUTPUT_IMG" "$IMG_MOUNT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount new image file"
    echo "Attempting alternative mount method..."
    
    # Try with explicit loop device
    LOOP_DEV=$(losetup -f)
    if [ -n "$LOOP_DEV" ]; then
        losetup "$LOOP_DEV" "$OUTPUT_IMG"
        mount -t ext4 "$LOOP_DEV" "$IMG_MOUNT"
        if [ $? -ne 0 ]; then
            echo "ERROR: Alternative mount method also failed"
            losetup -d "$LOOP_DEV" 2>/dev/null
            rm -f "$OUTPUT_IMG"
            umount "$MOUNT_POINT"
            exit 1
        fi
    else
        echo "ERROR: No loop devices available"
        rm -f "$OUTPUT_IMG"
        umount "$MOUNT_POINT"
        exit 1
    fi
fi
echo "✓ New image mounted at $IMG_MOUNT"

# Count files for progress
echo "Counting files..."
TOTAL_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
echo "Total files to copy: $TOTAL_FILES"
echo ""

# Copy with best available method
if command -v rsync &> /dev/null; then
    echo "Using rsync with progress..."
    rsync -ah --info=progress2 "${MOUNT_POINT}/" "$IMG_MOUNT/"
    COPY_RESULT=$?
elif command -v pv &> /dev/null; then
    echo "Using tar with pv progress..."
    tar -cf - -C "${MOUNT_POINT}" . | \
        pv -s $(du -sb "${MOUNT_POINT}" | awk '{print $1}') | \
        tar -xf - -C "$IMG_MOUNT"
    COPY_RESULT=$?
else
    echo "Using cp with periodic updates..."
    (cd "${MOUNT_POINT}" && cp -a . "$IMG_MOUNT/") &
    CP_PID=$!
    
    while kill -0 $CP_PID 2>/dev/null; do
        sleep 10
        CURRENT=$(find "$IMG_MOUNT" -type f 2>/dev/null | wc -l)
        if [ $TOTAL_FILES -gt 0 ]; then
            PERCENT=$((CURRENT * 100 / TOTAL_FILES))
            echo "Progress: $CURRENT/$TOTAL_FILES files ($PERCENT%)"
        fi
    done
    
    wait $CP_PID
    COPY_RESULT=$?
fi

echo ""
if [ $COPY_RESULT -ne 0 ]; then
    echo "WARNING: Copy completed with errors (exit code: $COPY_RESULT)"
else
    echo "✓ Copy completed successfully"
fi

echo ""
echo "[8/8] Verifying and finalizing..."

# Verify BEFORE unmounting
echo "Verifying image contents..."
if [ ! -d "$IMG_MOUNT/etc" ] || [ ! -d "$IMG_MOUNT/bin" ]; then
    echo "⚠ WARNING: Critical directories missing in image!"
    echo "Contents of image mount:"
    ls -la "$IMG_MOUNT" | head -15
    ALL_DIRS_EXIST=false
else
    echo "Checking directory structure..."
    ALL_DIRS_EXIST=true
    for dir in etc bin usr var home root; do
        if [ -d "$IMG_MOUNT/$dir" ]; then
            echo "  ✓ /$dir exists"
        else
            echo "  ✗ /$dir MISSING"
            ALL_DIRS_EXIST=false
        fi
    done
    
    # Check AlpHybris-specific directory
    if [ -d "$IMG_MOUNT/usr/bin/droid" ]; then
        echo "  ✓ /usr/bin/droid exists (AlpHybris specific)"
    else
        echo "  ⚠ /usr/bin/droid missing"
    fi
    
    # Count final files
    FINAL_FILES=$(find "$IMG_MOUNT" -type f 2>/dev/null | wc -l)
    echo "Files in image: $FINAL_FILES / $TOTAL_FILES"
fi

# Sync and unmount
echo ""
echo "Syncing filesystem..."
sync
sleep 3

echo "Unmounting new image..."
umount "$IMG_MOUNT"
if [ $? -ne 0 ]; then
    echo "Forcing unmount..."
    umount -f "$IMG_MOUNT" 2>/dev/null
    
    # Try to detach loop device
    LOOP_DEV=$(losetup -j "$OUTPUT_IMG" | cut -d: -f1)
    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV" 2>/dev/null
    fi
fi

# Clean up mount point
rmdir "$IMG_MOUNT" 2>/dev/null

# Unmount partition 77
echo "Unmounting partition 77..."
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT" 2>/dev/null

# Final sync
sync
sleep 2

echo ""
echo "Final image information:"
if [ -f "$OUTPUT_IMG" ]; then
    FINAL_SIZE=$(ls -lh "$OUTPUT_IMG" | awk '{print $5}')
    echo "Location: $OUTPUT_IMG"
    echo "Size: $FINAL_SIZE"
    
    # Quick filesystem check
    echo ""
    echo "Running filesystem check..."
    e2fsck -n "$OUTPUT_IMG" 2>&1 | grep -E "(errors|clean)" || echo "Check completed"
else
    echo "ERROR: Output image not found!"
    ALL_DIRS_EXIST=false
fi

echo ""
echo "========================================"
if [ "$ALL_DIRS_EXIST" = true ]; then
    echo "✓ REPACKAGING COMPLETED SUCCESSFULLY"
else
    echo "⚠ REPACKAGING COMPLETED WITH WARNINGS"
    echo ""
    echo "The image was created but verification found issues."
    echo "You may want to:"
    echo "1. Check available disk space"
    echo "2. Verify the source directory is intact"
    echo "3. Try the operation again"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Source: ${DEVICE}p77:/ (partition root)"
echo "- Output: $OUTPUT_IMG"
echo "- Size: ${FINAL_SIZE:-'Unknown'}"
echo "- Files: ${FINAL_FILES:-'Unknown'}/${TOTAL_FILES}"
echo ""
echo "The image can be used for reinstallation or distribution."
