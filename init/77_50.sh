#!/sbin/sh
#
# UMS512 Install AlpHybris API30 Rootfs to Partition 77
# Installs alphybris-api30-rootfs.img from SD card to /dev/block/mmcblk0p77
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SUPER_PARTITION="/dev/block/mmcblk0p50"
SD_CARD="/external_sd"
ALPHYBRIS_IMG="${SD_CARD}/alphybris-api30-rootfs.img"
MOUNT_POINT="/tmp/p77_mount"

echo "========================================"
echo "UMS512 AlpHybris API30 Installation Script"
echo "Install alphybris to mmcblk0p77"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Mount the partition"
echo "3. Extract alphybris-api30-rootfs.img contents to partition root"
echo "4. Extract vendor from super partition to /var/lib/lxc/android/vendor.img"
sleep 5

echo ""
echo "[1/10] Checking if alphybris-api30-rootfs.img exists..."
if [ ! -f "$ALPHYBRIS_IMG" ]; then
    echo "ERROR: $ALPHYBRIS_IMG not found!"
    echo "Please ensure alphybris-api30-rootfs.img is on your SD card at: $SD_CARD"
    echo ""
    echo "Available files in $SD_CARD:"
    ls -lh "$SD_CARD"/*.img 2>/dev/null || echo "No .img files found"
    exit 1
fi
echo "✓ Found alphybris-api30-rootfs.img at $ALPHYBRIS_IMG"
IMG_SIZE=$(ls -lh "$ALPHYBRIS_IMG" | awk '{print $5}')
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
echo "Checking super partition at $SUPER_PARTITION..."
if [ ! -b "$SUPER_PARTITION" ]; then
    echo "ERROR: Super partition $SUPER_PARTITION does not exist!"
    exit 1
fi
echo "✓ Super partition exists: $SUPER_PARTITION"

echo ""
echo "[3/10] Checking required tools..."
MISSING_TOOLS=""

if ! command -v mke2fs &> /dev/null; then
    MISSING_TOOLS="${MISSING_TOOLS}mke2fs "
fi

if ! command -v mount &> /dev/null; then
    MISSING_TOOLS="${MISSING_TOOLS}mount "
fi

if ! command -v dd &> /dev/null; then
    MISSING_TOOLS="${MISSING_TOOLS}dd "
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
echo "[8/10] Preparing partition for extraction..."
echo "✓ Partition ready - will extract to root"

echo ""
echo "[9/10] Installing AlpHybris rootfs to partition root..."
echo "This may take several minutes depending on image size (2.5GB)..."
echo "Copy method: $COPY_METHOD"
echo ""

# Mount alphybris-api30-rootfs.img
ALPHYBRIS_MOUNT="/tmp/alphybris_mount"
mkdir -p "$ALPHYBRIS_MOUNT" 2>/dev/null

echo "Mounting alphybris-api30-rootfs.img..."
mount -t ext4 -o loop "$ALPHYBRIS_IMG" "$ALPHYBRIS_MOUNT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount alphybris-api30-rootfs.img"
    echo "Image info:"
    file "$ALPHYBRIS_IMG" 2>/dev/null || echo "Cannot determine file type"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ alphybris-api30-rootfs.img mounted"
echo ""

# Verify mounted image has expected directories
echo "Verifying image contents..."
if [ ! -d "$ALPHYBRIS_MOUNT/etc" ] || [ ! -d "$ALPHYBRIS_MOUNT/bin" ]; then
    echo "ERROR: Image does not contain expected Alpine directories"
    echo "Contents of image:"
    ls -la "$ALPHYBRIS_MOUNT" | head -20
    umount "$ALPHYBRIS_MOUNT"
    umount "$MOUNT_POINT"
    exit 1
fi
echo "✓ Image contents verified"
echo ""

# Count total files for progress tracking
echo "Counting files in image..."
TOTAL_FILES=$(find "$ALPHYBRIS_MOUNT" -type f 2>/dev/null | wc -l)
echo "Total files to copy: $TOTAL_FILES"
echo ""

echo "Starting copy operation..."
echo "============================================"

# Use appropriate copy method
case "$COPY_METHOD" in
    rsync)
        # Best option - shows detailed progress
        rsync -ah --info=progress2 "$ALPHYBRIS_MOUNT/" "${MOUNT_POINT}/"
        COPY_RESULT=$?
        ;;
    
    pv)
        # Good option - shows transfer rate
        tar -cf - -C "$ALPHYBRIS_MOUNT" . | \
            pv -s $(du -sb "$ALPHYBRIS_MOUNT" | awk '{print $1}') | \
            tar -xf - -C "${MOUNT_POINT}"
        COPY_RESULT=$?
        ;;
    
    cp)
        # Fallback - show periodic updates
        echo "Copying files (periodic updates every 10 seconds)..."
        COPIED=0
        
        # Run cp in background
        (cd "$ALPHYBRIS_MOUNT" && cp -a . "${MOUNT_POINT}/") &
        CP_PID=$!
        
        # Monitor progress
        while kill -0 $CP_PID 2>/dev/null; do
            sleep 10
            CURRENT_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
            CURRENT_SIZE=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}')
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
echo "Unmounting alphybris-api30-rootfs.img..."
umount "$ALPHYBRIS_MOUNT"
rmdir "$ALPHYBRIS_MOUNT" 2>/dev/null

#
# === NEW: extract ONLY vendor from super partition ===
#
echo ""
echo "Extracting vendor image from super partition..."

# Create temporary directory for extraction
TEMP_DIR="${MOUNT_POINT}/super_temp"
mkdir -p "$TEMP_DIR" 2>/dev/null

# Create LXC android directory for vendor.img
mkdir -p "${MOUNT_POINT}/var/lib/lxc/android" 2>/dev/null

# Helper to extract a raw image from super partition
extract_super_partition_img() {
    local name="$1"
    local start_sector="$2"
    local num_sectors="$3"
    local destination="$4"  # Full path to final .img location
    local temp_img="${TEMP_DIR}/${name}.img"

    # 512-byte sectors, 4096-byte blocks -> divide by 8
    local skip_blocks=$((start_sector / 8))
    local count_blocks=$((num_sectors / 8))

    echo ""
    echo "  -> Extracting ${name}.img from super partition"
    echo "     (start=${start_sector}, sectors=${num_sectors})"
    echo "     skip=${skip_blocks} blocks, count=${count_blocks} blocks, bs=4096"
    
    dd if="$SUPER_PARTITION" of="$temp_img" bs=4096 skip=$skip_blocks count=$count_blocks 2>/dev/null

    if [ $? -ne 0 ] || [ ! -f "$temp_img" ]; then
        echo "  ✗ Failed to extract ${name}.img"
        return 1
    else
        echo "  ✓ Extracted to temp: $temp_img"
        
        # Move to final location
        echo "  -> Moving to: $destination"
        mv "$temp_img" "$destination" 2>/dev/null
        
        if [ -f "$destination" ]; then
            IMG_SIZE=$(ls -lh "$destination" | awk '{print $5}')
            echo "  ✓ Created ${name}.img (${IMG_SIZE})"
            return 0
        else
            echo "  ✗ Failed to move ${name}.img to destination"
            return 1
        fi
    fi
}

# Extract ONLY vendor partition to /var/lib/lxc/android/vendor.img
# Values from your original mount_partition configuration:
# mount_partition "vendor" 3436544 3700976
echo ""
echo "Extracting vendor to /var/lib/lxc/android/vendor.img..."
extract_super_partition_img "vendor" 3436544 3700976 "${MOUNT_POINT}/var/lib/lxc/android/vendor.img"
VENDOR_RESULT=$?

# Clean up temp directory
echo ""
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR" 2>/dev/null
echo "✓ Cleanup complete"

sync
echo ""

echo ""
echo "[10/10] Final verification..."
echo "Checking Alpine rootfs contents:"
ls -la "${MOUNT_POINT}" | head -20
echo ""
echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""
echo "File count verification:"
FINAL_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
echo "Files copied: $FINAL_FILES / $TOTAL_FILES"

# Verify critical Alpine directories
echo ""
echo "Verifying Alpine directory structure..."
ALL_DIRS_EXIST=true
for dir in etc bin usr var home root; do
    if [ -d "${MOUNT_POINT}/$dir" ]; then
        echo "  ✓ /$dir exists"
    else
        echo "  ✗ /$dir MISSING"
        ALL_DIRS_EXIST=false
    fi
done

# Verify AlpHybris-specific directory
echo ""
echo "Verifying AlpHybris components..."
if [ -d "${MOUNT_POINT}/usr/bin/droid" ]; then
    echo "  ✓ /usr/bin/droid exists (AlpHybris specific)"
else
    echo "  ⚠ /usr/bin/droid missing"
fi

# Verify the extracted vendor image
echo ""
echo "Verifying vendor.img in /var/lib/lxc/android/..."

if [ -f "${MOUNT_POINT}/var/lib/lxc/android/vendor.img" ]; then
    VENDOR_SIZE=$(ls -lh "${MOUNT_POINT}/var/lib/lxc/android/vendor.img" | awk '{print $5}')
    echo "  ✓ vendor.img exists (${VENDOR_SIZE})"
else
    echo "  ✗ vendor.img MISSING"
    ALL_DIRS_EXIST=false
fi

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
if [ "$ALL_DIRS_EXIST" = true ]; then
    echo "✓ ALPHYBRIS INSTALLATION COMPLETED SUCCESSFULLY"
else
    echo "⚠ ALPHYBRIS INSTALLATION COMPLETED WITH WARNINGS"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition: ${DEVICE}p77"
echo "- Filesystem: ext4"
echo "- AlpHybris rootfs installed to: / (partition root)"
echo "- Extracted from super: vendor -> /var/lib/lxc/android/vendor.img"
echo "- Files copied: $FINAL_FILES"
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
