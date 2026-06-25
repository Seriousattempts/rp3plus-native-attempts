#!/sbin/sh
#
# UMS512 - Alpine Install Script
# 1. Install Alpine rootfs to Partition 77 (from alpine.tar.gz)
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
ALPINE_TAR="${SD_CARD}/alpine.tar.gz"
MOUNT_POINT="/tmp/p77_mount"

# File count trackers
ALPINE_TOTAL_FILES=0
TOTAL_PARTITION_FILES=0

echo "========================================"
echo "UMS512 Alpine Installation Script"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Extract alpine.tar.gz to partition root"
sleep 5

# ============================================================
# [1/8] CHECK REQUIRED FILES
# ============================================================
echo ""
echo "[1/8] Checking required files..."

if [ ! -f "$ALPINE_TAR" ]; then
    echo "ERROR: $ALPINE_TAR not found!"
    echo "Please ensure alpine.tar.gz is on your SD card at: $SD_CARD"
    echo ""
    echo "Available files in $SD_CARD:"
    ls -lh "$SD_CARD"/*.tar.gz 2>/dev/null || echo "No .tar.gz files found"
    exit 1
fi
echo "Found alpine.tar.gz"
ALPINE_SIZE=$(ls -lh "$ALPINE_TAR" | awk '{print $5}')
echo "  Size: $ALPINE_SIZE"

# ============================================================
# [2/8] CHECK PARTITIONS
# ============================================================
echo ""
echo "[2/8] Checking partitions..."

if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    exit 1
fi
echo "Partition 77 exists: ${DEVICE}p${PARTITION_77}"

# ============================================================
# [3/8] CHECK REQUIRED TOOLS
# ============================================================
echo ""
echo "[3/8] Checking required tools..."
MISSING_TOOLS=""

for tool in mke2fs mount dd tar cp; do
    if ! command -v $tool > /dev/null 2>&1; then
        MISSING_TOOLS="${MISSING_TOOLS}$tool "
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools: $MISSING_TOOLS"
    exit 1
fi
echo "All required tools available"

# Check for progress tools (used during Alpine extraction)
if command -v rsync > /dev/null 2>&1; then
    COPY_METHOD="rsync"
    echo "rsync available - will use with progress display"
elif command -v pv > /dev/null 2>&1; then
    COPY_METHOD="pv"
    echo "pv available - will use with progress display"
else
    COPY_METHOD="tar"
    echo "Using basic tar extraction"
fi

# ============================================================
# [4/8] UNMOUNT PARTITION 77 IF MOUNTED
# ============================================================
echo ""
echo "[4/8] Unmounting partition 77 if mounted..."
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    echo "Unmounting ${DEVICE}p${PARTITION_77}..."
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        echo "ERROR: Could not unmount ${DEVICE}p${PARTITION_77}"
        exit 1
    fi
fi
echo "Partition 77 is not mounted"

# ============================================================
# [5/8] GET PARTITION SIZE
# ============================================================
echo ""
echo "[5/8] Getting partition size..."
PARTITION_SIZE=$(cat /proc/partitions | grep "mmcblk0p${PARTITION_77}" | awk '{print $3}')
if [ -z "$PARTITION_SIZE" ]; then
    echo "ERROR: Could not determine partition size"
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

# ============================================================
# [6/8] FORMAT PARTITION 77 AS EXT4
# ============================================================
echo ""
echo "[6/8] Formatting partition 77 as ext4..."
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
echo "ext4 filesystem created successfully"

sync
sleep 2

# ============================================================
# [7/8] MOUNT PARTITION 77
# ============================================================
echo ""
echo "[7/8] Mounting partition 77..."
mkdir -p "$MOUNT_POINT" 2>/dev/null

mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    echo "Partition info:"
    blkid ${DEVICE}p${PARTITION_77}
    exit 1
fi
echo "Partition 77 mounted at $MOUNT_POINT"

# ============================================================
# [8/8] INSTALL ALPINE ROOTFS TO PARTITION ROOT
# ============================================================
echo ""
echo "[8/8] Installing Alpine rootfs to partition root..."

echo "Counting files in alpine.tar.gz..."
ALPINE_TOTAL_FILES=$(tar -tzf "$ALPINE_TAR" 2>/dev/null | wc -l)
echo "Total archive entries to extract: $ALPINE_TOTAL_FILES"
echo ""

echo "Starting Alpine extraction to partition root..."
echo "============================================"
case "$COPY_METHOD" in
    rsync)
        ALPINE_TEMP="/tmp/alpine_extract"
        mkdir -p "$ALPINE_TEMP" 2>/dev/null
        tar -xpzf "$ALPINE_TAR" -C "$ALPINE_TEMP"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to extract alpine.tar.gz to temp directory"
            umount "$MOUNT_POINT"
            exit 1
        fi
        rsync -ah --info=progress2 "$ALPINE_TEMP/" "${MOUNT_POINT}/"
        COPY_RESULT=$?
        rm -rf "$ALPINE_TEMP" 2>/dev/null
        ;;

    pv)
        pv "$ALPINE_TAR" | tar -xpzf - -C "${MOUNT_POINT}"
        COPY_RESULT=$?
        ;;

    tar)
        tar -xpzf "$ALPINE_TAR" -C "${MOUNT_POINT}" &
        TAR_ROOT_PID=$!
        while kill -0 $TAR_ROOT_PID 2>/dev/null; do
            sleep 10
            CURRENT_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
            CURRENT_SIZE=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}')
            echo "Progress: $CURRENT_FILES files extracted - Size: $CURRENT_SIZE"
        done
        wait $TAR_ROOT_PID
        COPY_RESULT=$?
        ;;
esac
echo "============================================"

if [ $COPY_RESULT -ne 0 ]; then
    echo "WARNING: Alpine extraction reported errors (exit code: $COPY_RESULT)"
else
    echo "Alpine extraction completed successfully"
fi

ALPINE_TOTAL_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
echo "Alpine files on partition: $ALPINE_TOTAL_FILES"

sync
sleep 2

# ============================================================
# FINAL VERIFICATION
# ============================================================
echo ""
echo "[Final] Final verification..."

echo "Checking partition root contents:"
ls -la "${MOUNT_POINT}" | head -20
echo ""

echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""

TOTAL_PARTITION_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)

echo "Verifying Alpine directory structure..."
ALL_DIRS_EXIST=true
for dir in etc bin usr var home root; do
    if [ -d "${MOUNT_POINT}/$dir" ]; then
        echo "  /$dir exists"
    else
        echo "  /$dir MISSING"
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
if [ "$ALL_DIRS_EXIST" = true ] && [ $COPY_RESULT -eq 0 ]; then
    echo "INSTALLATION COMPLETED SUCCESSFULLY"
else
    echo "INSTALLATION COMPLETED WITH WARNINGS/ERRORS"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition:             ${DEVICE}p77"
echo "- Filesystem:            ext4"
echo "- Alpine rootfs at:      / (partition root) - $ALPINE_TOTAL_FILES files"
echo "- Total partition files: $TOTAL_PARTITION_FILES"
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