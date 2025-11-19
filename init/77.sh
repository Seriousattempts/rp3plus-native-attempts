#!/sbin/sh
#
# UMS512 Format Partition 77 (linuxdata) as ext4
# Run AFTER TWRP Format Data has been completed
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77

echo "========================================"
echo "UMS512 Format Partition 77 Script"
echo "Format mmcblk0p77 as ext4"
echo "========================================"
echo ""
echo "This script formats partition 77 (linuxdata) as ext4"
sleep 5

echo ""
echo "[1/8] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    echo ""
    echo "Partition table:"
    sgdisk --print $DEVICE | grep -E "(Number|76|77|78)"
    exit 1
fi
echo "✓ Partition 77 exists: ${DEVICE}p${PARTITION_77}"

echo ""
echo "[2/8] Checking tools..."
if ! command -v mke2fs &> /dev/null; then
    echo "ERROR: mke2fs not found"
    exit 1
fi
echo "✓ mke2fs found"

if ! command -v e2fsck &> /dev/null; then
    echo "WARNING: e2fsck not found - cannot verify filesystem after formatting"
    E2FSCK_AVAILABLE=false
else
    echo "✓ e2fsck found"
    E2FSCK_AVAILABLE=true
fi

# Check with xxd like the user did
echo ""
echo "Raw partition header check (xxd -s 0x400 -l 16):"
echo "P76 header:"
xxd -s 0x400 -l 16 ${DEVICE}p76 2>/dev/null || echo "  Cannot read partition 76"

echo "P77 header:"
xxd -s 0x400 -l 16 ${DEVICE}p77 2>/dev/null || echo "  Cannot read partition 77"

echo ""
echo "[3/8] Unmounting partition 77 if mounted..."
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    echo "Unmounting ${DEVICE}p${PARTITION_77}..."
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        echo "ERROR: Could not unmount ${DEVICE}p${PARTITION_77}"
        echo "Currently mounted:"
        mount | grep "${DEVICE}p${PARTITION_77}"
        exit 1
    fi
fi
echo "✓ Partition 77 is not mounted"

echo ""
echo "[4/8] Getting partition size..."
PARTITION_SIZE=$(cat /proc/partitions | grep "mmcblk0p${PARTITION_77}" | awk '{print $3}')
if [ -z "$PARTITION_SIZE" ]; then
    echo "ERROR: Could not determine partition size"
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

echo ""
echo "[5/8] Wiping partition header and creating ext4 filesystem..."
echo "Wiping first 1MB of partition..."
dd if=/dev/zero of=${DEVICE}p${PARTITION_77} bs=1M count=1 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Could not wipe partition header"
    exit 1
fi

echo "Creating ext4 filesystem on ${DEVICE}p${PARTITION_77}..."
mke2fs -F -t ext4 -b 4096 -L linuxdata ${DEVICE}p${PARTITION_77}
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create ext4 filesystem"
    echo ""
    echo "Debugging information:"
    echo "Device exists: $([ -b ${DEVICE}p${PARTITION_77} ] && echo 'YES' || echo 'NO')"
    echo "Device permissions:"
    ls -l ${DEVICE}p${PARTITION_77}
    echo ""
    echo "Trying alternative format method..."
    mkfs.ext4 -F ${DEVICE}p${PARTITION_77} 2>&1

    if [ $? -ne 0 ]; then
        echo "ERROR: Alternative format method also failed"
        exit 1
    else
        echo "✓ Alternative format method succeeded"
    fi
else
    echo "✓ ext4 filesystem created successfully"
fi

# Sync to ensure writes are committed
sync
sleep 2

echo ""
echo "[6/8] Verifying filesystem..."
if [ "$E2FSCK_AVAILABLE" = true ]; then
    echo "Running filesystem check..."
    e2fsck -f -y ${DEVICE}p${PARTITION_77} 2>&1 | head -10
    if [ $? -eq 0 ]; then
        echo "✓ Filesystem check passed"
    else
        echo "WARNING: Filesystem check had issues (but may still be usable)"
    fi
else
    echo "Skipping filesystem check (e2fsck not available)"
fi

# Verify with blkid
echo "Verifying with blkid:"
blkid ${DEVICE}p${PARTITION_77}
if [ $? -eq 0 ]; then
    echo "✓ Filesystem detected by blkid"
else
    echo "WARNING: Filesystem not detected by blkid"
fi

# Test with xxd again
echo ""
echo "Verifying ext4 signature with xxd:"
echo "P77 header after formatting:"
xxd -s 0x400 -l 16 ${DEVICE}p77

# Look for ext4 signature (0x53EF at offset 0x438)
EXT4_SIG=$(xxd -s 0x438 -l 2 -p ${DEVICE}p77 2>/dev/null)
if [ "$EXT4_SIG" = "53ef" ]; then
    echo "✓ ext4 signature found (53ef)"
elif [ "$EXT4_SIG" = "ef53" ]; then
    echo "✓ ext4 signature found (ef53 - byte swapped)"
else
    echo "WARNING: ext4 signature not found at expected location"
    echo "Found signature: $EXT4_SIG"
fi

echo ""
echo "[7/8] Final verification and mount test..."
mkdir -p /tmp/test_mount 2>/dev/null

echo "Testing mount..."
mount -t ext4 ${DEVICE}p${PARTITION_77} /tmp/test_mount
if [ $? -eq 0 ]; then
    echo "✓ Successfully mounted partition 77 as ext4"

    # Create test file
    echo "test" > /tmp/test_mount/test_file.txt
    if [ -f /tmp/test_mount/test_file.txt ]; then
        echo "✓ Write test successful"
        rm /tmp/test_mount/test_file.txt
    else
        echo "WARNING: Write test failed"
    fi

    # Get filesystem info
    df -h /tmp/test_mount | tail -1

    umount /tmp/test_mount
    echo "✓ Unmounted successfully"
else
    echo "ERROR: Could not mount partition 77 as ext4"
    echo "This indicates the formatting failed"
    exit 1
fi

rmdir /tmp/test_mount 2>/dev/null

echo ""
echo "========================================"
echo "✓ PARTITION 77 FORMAT COMPLETED"
echo "========================================"
echo ""
echo "Final status:"
echo ""
echo "Partition 77 is now ready for use as ext4 filesystem"
echo "You can mount it with: mount -t ext4 ${DEVICE}p77 /mnt/linuxdata"
echo "[8/8] Manual work..."
echo "You must now click the middle home button"
echo "Click Wipe"
echo "Click Advanced Wipe"
echo "Select metadata, Data"
echo "Swipe to Wipe"
echo "Reboot to System"
