#!/sbin/sh
#
# UMS512 Userdata Partition Split Script with TWRP Format Data
# Partition 76: userdata (F2FS)
# Partition 77: linuxdata (ext4)
# Replicates TWRP's Format Data procedure

DEVICE="/dev/block/mmcblk0"
PARTITION_NUM=76
NEW_PARTITION_NUM=77
METADATA_PARTITION=58

echo "========================================"
echo "UMS512 Partition Split + Format Data"
echo "P76: F2FS | P77: ext4"
echo "========================================"

echo ""
echo "[1/13] Checking tools..."
if ! command -v sgdisk &> /dev/null; then
    echo "ERROR: sgdisk not found"
    exit 1
fi

# Check for F2FS tool
if ! command -v mkfs.f2fs &> /dev/null; then
    if ! command -v make_f2fs &> /dev/null; then
        echo "ERROR: No F2FS tool found"
        exit 1
    fi
    F2FS_CMD="make_f2fs"
else
    F2FS_CMD="mkfs.f2fs"
fi
echo "✓ F2FS tool: $F2FS_CMD"

# Check for ext4 tool
if ! command -v mke2fs &> /dev/null; then
    echo "ERROR: mke2fs not found"
    exit 1
fi
echo "✓ ext4 tool: mke2fs"

echo ""
echo "[2/13] Stopping Android services that may lock partitions..."
# Kill vold (volume daemon) that manages /data
killall vold 2>/dev/null || true
# Kill logd if running
killall logd 2>/dev/null || true
sleep 2

echo ""
echo "[3/13] Unmounting all data-related mounts..."
# Unmount everything that might be using userdata/metadata
umount /data 2>/dev/null || true
umount /sdcard 2>/dev/null || true
umount ${DEVICE}p${PARTITION_NUM} 2>/dev/null || true
umount ${DEVICE}p${METADATA_PARTITION} 2>/dev/null || true

# Force unmount if still mounted
if mount | grep -q "/data"; then
    echo "Force unmounting /data..."
    umount -f /data 2>/dev/null || true
    umount -l /data 2>/dev/null || true
fi

sleep 2
echo "✓ Unmounted"

echo ""
echo "[4/13] Getting partition info..."

# Check if partition 77 already exists
PARTITION_77_EXISTS=$(sgdisk --print $DEVICE | awk "/^ *$NEW_PARTITION_NUM/ {print \$1}")

if [ ! -z "$PARTITION_77_EXISTS" ]; then
    echo ""
    echo "========================================"
    echo "NOTICE: Partition $NEW_PARTITION_NUM already exists!"
    echo "========================================"
    echo ""
    echo "Remounting data-related mounts..."
    
    # Remount the partitions that were unmounted in step 3
    mount ${DEVICE}p${PARTITION_NUM} /data 2>/dev/null || true
    mount ${DEVICE}p${METADATA_PARTITION} 2>/dev/null || true
    
    echo "✓ Remounted"
    echo ""
    echo "========================================"
    echo "Script completed."
    echo "Partition $NEW_PARTITION_NUM has already been"
    echo "created for ums5121h10-3plus edition."
    echo "========================================"
    exit 0
fi

START_SECTOR=$(sgdisk --print $DEVICE | awk "/^ *$PARTITION_NUM/ {print \$2}")
END_SECTOR=$(sgdisk --print $DEVICE | awk "/^ *$PARTITION_NUM/ {print \$3}")

if [ -z "$START_SECTOR" ] || [ -z "$END_SECTOR" ]; then
    echo "ERROR: Cannot find partition $PARTITION_NUM"
    exit 1
fi

TOTAL_SECTORS=$((END_SECTOR - START_SECTOR + 1))
HALF_SECTORS=$((TOTAL_SECTORS / 2))
SPLIT_SECTOR=$((START_SECTOR + HALF_SECTORS - 1))
NEW_START=$((SPLIT_SECTOR + 1))

echo "Current partition $PARTITION_NUM:"
echo "  Start: $START_SECTOR, End: $END_SECTOR"
echo "  Total sectors: $TOTAL_SECTORS"
echo ""
echo "Split calculation:"
echo "  P$PARTITION_NUM: $START_SECTOR to $SPLIT_SECTOR (F2FS)"
echo "  P$NEW_PARTITION_NUM: $NEW_START to $END_SECTOR (ext4)"

echo ""
echo "[5/13] Backing up partition table..."
sgdisk --backup=/tmp/partition_backup.gpt $DEVICE
if [ $? -eq 0 ]; then
    echo "✓ Backup saved to /tmp/partition_backup.gpt"
else
    echo "WARNING: Could not create backup"
fi

echo ""
echo "[6/13] Deleting partition $PARTITION_NUM..."
sgdisk --delete=$PARTITION_NUM $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to delete partition $PARTITION_NUM"
    exit 1
fi
echo "✓ Deleted"

echo ""
echo "[7/13] Creating partition $PARTITION_NUM (first half)..."
sgdisk --new=$PARTITION_NUM:$START_SECTOR:$SPLIT_SECTOR $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create partition $PARTITION_NUM"
    echo "Restoring original partition..."
    sgdisk --new=$PARTITION_NUM:$START_SECTOR:$END_SECTOR $DEVICE
    exit 1
fi
echo "✓ Created partition $PARTITION_NUM"

echo ""
echo "[8/13] Creating partition $NEW_PARTITION_NUM (second half)..."
sgdisk --new=$NEW_PARTITION_NUM:$NEW_START:$END_SECTOR $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create partition $NEW_PARTITION_NUM"
    exit 1
fi
echo "✓ Created partition $NEW_PARTITION_NUM"

echo ""
echo "[9/13] Setting partition names..."
sgdisk --change-name=$PARTITION_NUM:userdata $DEVICE
sgdisk --change-name=$NEW_PARTITION_NUM:linuxdata $DEVICE
echo "✓ Names set"

echo ""
echo "[10/13] Refreshing partition table (ignoring errors)..."
# Try blockdev but don't fail if it's busy
blockdev --rereadpt $DEVICE 2>&1 | grep -v "Device or resource busy" || true
sync
sleep 3

# Force kernel to recognize by triggering uevent
echo 1 > /sys/block/mmcblk0/uevent 2>/dev/null || true
sleep 2

echo ""
echo "[11/13] Waiting for kernel to recognize partitions..."
WAIT_COUNT=0
MAX_WAIT=3

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -b "${DEVICE}p${PARTITION_NUM}" ] && [ -b "${DEVICE}p${NEW_PARTITION_NUM}" ]; then
        echo "✓ Both partitions recognized by kernel"
        break
    fi
    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo "Waiting for block devices... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 1
done

if [ ! -b "${DEVICE}p${PARTITION_NUM}" ]; then
    echo "WARNING: ${DEVICE}p${PARTITION_NUM} not visible yet"
    echo "Continuing anyway - will try formatting"
fi

if [ ! -b "${DEVICE}p${NEW_PARTITION_NUM}" ]; then
    echo "WARNING: ${DEVICE}p${NEW_PARTITION_NUM} not visible yet"
    echo "Continuing anyway - will try formatting"
fi

echo ""
echo "[12/13] TWRP Format Data Procedure - Formatting metadata..."
# This is what TWRP does when you Format Data
echo "Wiping encryption footer..."
dd if=/dev/zero of=${DEVICE}p${PARTITION_NUM} bs=1M count=10 2>/dev/null || true

echo "Formatting metadata partition (removes encryption)..."
mke2fs -F -t ext4 ${DEVICE}p${METADATA_PARTITION}
if [ $? -ne 0 ]; then
    echo "WARNING: Could not format metadata partition"
else
    echo "✓ Metadata partition formatted"
fi

# Remove encryption keys
if [ -d /data/unencrypted ]; then
    rm -rf /data/unencrypted/* 2>/dev/null || true
fi

# Wipe misc partition encryption flags
if [ -b /dev/block/by-name/misc ]; then
    dd if=/dev/zero of=/dev/block/by-name/misc bs=4096 count=1 2>/dev/null || true
fi

sync
sleep 2

echo ""
echo "[13/13] Manual work..."
echo "You must now click the middle home button"
echo "Click REBOOT"
echo "Click Recovery"