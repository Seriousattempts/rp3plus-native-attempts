#!/sbin/sh
#
# UMS512 Userdata Partition Split Script with TWRP Format Data
# Partition 76: userdata (F2FS) - Dynamic Size
# Partition 77: linuxdata (ext4) - Dynamic Size
# Partition 78: rawblock (2GB, unformatted)
# Replicates TWRP's Format Data procedure

DEVICE="/dev/block/mmcblk0"
PARTITION_NUM=76
NEW_PARTITION_NUM=77
RAW_PARTITION_NUM=78
METADATA_PARTITION=58

echo "========================================"
echo "UMS512 Partition Split + Format Data"
echo "P76: F2FS | P77: ext4 | P78: Raw (2GB)"
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

# Check if partition 77 or 78 already exists
PARTITION_77_EXISTS=$(sgdisk --print $DEVICE | awk "/^ *$NEW_PARTITION_NUM/ {print \$1}")
PARTITION_78_EXISTS=$(sgdisk --print $DEVICE | awk "/^ *$RAW_PARTITION_NUM/ {print \$1}")

if [ ! -z "$PARTITION_77_EXISTS" ] || [ ! -z "$PARTITION_78_EXISTS" ]; then
    echo ""
    echo "========================================"
    echo "NOTICE: Partitions already exist!"
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
    echo "Partitions have already been created."
    echo "========================================"
    exit 0
fi

START_SECTOR=$(sgdisk --print $DEVICE | awk "/^ *$PARTITION_NUM/ {print \$2}")
END_SECTOR=$(sgdisk --print $DEVICE | awk "/^ *$PARTITION_NUM/ {print \$3}")

if [ -z "$START_SECTOR" ] || [ -z "$END_SECTOR" ]; then
    echo "ERROR: Cannot find partition $PARTITION_NUM"
    exit 1
fi

# Calculate sizes safely using awk to avoid 32-bit integer overflow in TWRP shell
TOTAL_SECTORS=$(awk "BEGIN {printf \"%.0f\", $END_SECTOR - $START_SECTOR + 1}")

# Calculate 2GB in sectors (assuming 512-byte sectors)
# 2GB = 2 * 1024 * 1024 * 1024 = 2147483648 bytes
# 2147483648 / 512 = 4194304 sectors
RAW_PARTITION_SECTORS=4194304

# Check if we have enough space
if awk "BEGIN {exit !($TOTAL_SECTORS <= $RAW_PARTITION_SECTORS)}"; then
    echo "ERROR: Partition too small to allocate 2GB for raw partition"
    exit 1
fi

# Calculate partition boundaries for the remainder safely
REMAINING_SECTORS=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SECTORS - $RAW_PARTITION_SECTORS}")
TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_SECTORS * 512 / 1073741824}")
REMAINING_GB=$(awk "BEGIN {printf \"%.2f\", $REMAINING_SECTORS * 512 / 1073741824}")

echo ""
echo "Current partition $PARTITION_NUM:"
echo "  Start: $START_SECTOR, End: $END_SECTOR"
echo "  Total size: $TOTAL_GB GB"
echo ""

echo "=========================================================="
echo "Available space for P76 and P77: $REMAINING_GB GB"
echo "(After reserving 2GB for P78)"
echo "=========================================================="
echo "Choose split ratio (P76 Userdata / P77 Linuxdata):"

# Calculate exact GB sizes for the menu safely using awk
for i in 1 2 3 4 5 6 7 8 9; do
    P76_PCT=$(( 100 - (i * 10) ))
    P77_PCT=$(( i * 10 ))
    
    P76_SEC_MENU=$(awk "BEGIN {printf \"%.0f\", $REMAINING_SECTORS * ($P76_PCT / 100)}")
    P77_SEC_MENU=$(awk "BEGIN {printf \"%.0f\", $REMAINING_SECTORS - $P76_SEC_MENU}")
    
    P76_GB=$(awk "BEGIN {printf \"%.2f\", $P76_SEC_MENU * 512 / 1073741824}")
    P77_GB=$(awk "BEGIN {printf \"%.2f\", $P77_SEC_MENU * 512 / 1073741824}")
    
    echo " [$i] $P76_PCT/$P77_PCT = $P76_GB GB | $P77_GB GB"
done
echo "=========================================================="
echo -n "Enter your choice (1-9): "
read SPLIT_CHOICE

case "$SPLIT_CHOICE" in
    1) PERCENT_76=90 ;;
    2) PERCENT_76=80 ;;
    3) PERCENT_76=70 ;;
    4) PERCENT_76=60 ;;
    5) PERCENT_76=50 ;;
    6) PERCENT_76=40 ;;
    7) PERCENT_76=30 ;;
    8) PERCENT_76=20 ;;
    9) PERCENT_76=10 ;;
    *) echo "Invalid choice. Defaulting to 50/50 split."; PERCENT_76=50 ;;
esac

# Execute final Sector Math based on choice using awk
P76_SECTORS=$(awk "BEGIN {printf \"%.0f\", $REMAINING_SECTORS * ($PERCENT_76 / 100)}")
P77_SECTORS=$(awk "BEGIN {printf \"%.0f\", $REMAINING_SECTORS - $P76_SECTORS}")

P76_END=$(awk "BEGIN {printf \"%.0f\", $START_SECTOR + $P76_SECTORS - 1}")
P77_START=$(awk "BEGIN {printf \"%.0f\", $P76_END + 1}")
P77_END=$(awk "BEGIN {printf \"%.0f\", $P77_START + $P77_SECTORS - 1}")
P78_START=$(awk "BEGIN {printf \"%.0f\", $P77_END + 1}")
P78_END=$END_SECTOR

echo ""
echo "Split calculation applied:"
echo "  P$PARTITION_NUM: $START_SECTOR to $P76_END (F2FS)"
echo "  P$NEW_PARTITION_NUM: $P77_START to $P77_END (ext4)"
echo "  P$RAW_PARTITION_NUM: $P78_START to $P78_END (Raw 2GB)"

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
echo "[7/13] Creating partition $PARTITION_NUM (userdata)..."
sgdisk --new=$PARTITION_NUM:$START_SECTOR:$P76_END $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create partition $PARTITION_NUM"
    echo "Restoring original partition..."
    sgdisk --new=$PARTITION_NUM:$START_SECTOR:$END_SECTOR $DEVICE
    exit 1
fi
echo "✓ Created partition $PARTITION_NUM"

echo ""
echo "[8/13] Creating partition $NEW_PARTITION_NUM (linuxdata)..."
sgdisk --new=$NEW_PARTITION_NUM:$P77_START:$P77_END $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create partition $NEW_PARTITION_NUM"
    exit 1
fi
echo "✓ Created partition $NEW_PARTITION_NUM"

echo ""
echo "[9/13] Creating partition $RAW_PARTITION_NUM (rawblock - 2GB)..."
sgdisk --new=$RAW_PARTITION_NUM:$P78_START:$P78_END $DEVICE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create partition $RAW_PARTITION_NUM"
    exit 1
fi
echo "✓ Created partition $RAW_PARTITION_NUM"

echo ""
echo "[10/13] Setting partition names..."
sgdisk --change-name=$PARTITION_NUM:userdata $DEVICE
sgdisk --change-name=$NEW_PARTITION_NUM:linuxdata $DEVICE
sgdisk --change-name=$RAW_PARTITION_NUM:rawblock $DEVICE
echo "✓ Names set"

echo ""
echo "[11/13] Refreshing partition table (ignoring errors)..."
# Try blockdev but don't fail if it's busy
blockdev --rereadpt $DEVICE 2>&1 | grep -v "Device or resource busy" || true
sync
sleep 3

# Force kernel to recognize by triggering uevent
echo 1 > /sys/block/mmcblk0/uevent 2>/dev/null || true
sleep 2

echo ""
echo "[12/13] Waiting for kernel to recognize partitions..."
WAIT_COUNT=0
MAX_WAIT=3

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -b "${DEVICE}p${PARTITION_NUM}" ] && [ -b "${DEVICE}p${NEW_PARTITION_NUM}" ] && [ -b "${DEVICE}p${RAW_PARTITION_NUM}" ]; then
        echo "✓ All partitions recognized by kernel"
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

if [ ! -b "${DEVICE}p${RAW_PARTITION_NUM}" ]; then
    echo "WARNING: ${DEVICE}p${RAW_PARTITION_NUM} not visible yet"
    echo "Partition will be available after reboot"
fi

echo ""
echo "[13/13] TWRP Format Data Procedure - Formatting metadata..."
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
echo "========================================"
echo "Partition creation complete!"
echo "========================================"
echo "P76 (userdata): F2FS - Android data"
echo "P77 (linuxdata): ext4 - Linux data"
echo "P78 (rawblock): Raw 2GB - Unformatted for ZRAM"
echo ""
echo "Manual work..."
echo "You must now click the middle home button"
echo "Click REBOOT"
echo "Click Recovery"
echo "========================================"