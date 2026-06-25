#!/sbin/sh
#
# UMS512 - Partition 77 Cleanup & Symlink Script
# Deletes specified folders from partition 77 root
# Creates /userdata -> /sdcard symlink
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
MOUNT_POINT="/tmp/p77_mount"

echo "========================================"
echo "UMS512 Partition 77 Cleanup Script"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Mount partition 77"
echo "2. Delete specified folders from the partition root"
echo "3. Create symlink: /userdata -> /sdcard"
echo ""

# Folders to delete at the partition root
DELETE_DIRS="
android
apex
proc
system
product
vendor
metadata
odm
cache
data
"

# Sub-paths to delete (relative to partition root)
DELETE_SUBPATHS="
var/lib/lxc
var/run
"

# ============================================================
# [1/4] CHECK PARTITION EXISTS
# ============================================================
echo "[1/4] Checking partition 77..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    exit 1
fi
echo "Partition 77 exists: ${DEVICE}p${PARTITION_77}"

# ============================================================
# [2/4] MOUNT PARTITION 77
# ============================================================
echo ""
echo "[2/4] Mounting partition 77..."

# Unmount first if already mounted
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    echo "Partition 77 already mounted, unmounting first..."
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        echo "ERROR: Could not unmount ${DEVICE}p${PARTITION_77}"
        exit 1
    fi
fi

mkdir -p "$MOUNT_POINT" 2>/dev/null
mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    blkid ${DEVICE}p${PARTITION_77}
    exit 1
fi
echo "Partition 77 mounted at $MOUNT_POINT"

# Show disk usage before
echo ""
echo "Disk usage before cleanup:"
df -h "$MOUNT_POINT"
echo ""
echo "Current partition root:"
ls -la "$MOUNT_POINT"

# ============================================================
# [3/4] DELETE SPECIFIED PATHS
# ============================================================
echo ""
echo "[3/4] Deleting specified paths..."
echo "========================================"

ALL_DELETE_OK=true

# Delete root-level directories
for dir in $DELETE_DIRS; do
    TARGET="${MOUNT_POINT}/${dir}"
    if [ -d "$TARGET" ]; then
        echo "Deleting /$dir ..."
        rm -rf "$TARGET"
        if [ $? -ne 0 ]; then
            echo "  WARNING: Failed to fully delete /$dir"
            ALL_DELETE_OK=false
        else
            echo "  /$dir  deleted"
        fi
    elif [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        echo "Deleting /$dir (file/symlink)..."
        rm -f "$TARGET"
        if [ $? -ne 0 ]; then
            echo "  WARNING: Failed to delete /$dir"
            ALL_DELETE_OK=false
        else
            echo "  /$dir  deleted"
        fi
    else
        echo "  /$dir  not found, skipping"
    fi
done

# Delete sub-paths
for subpath in $DELETE_SUBPATHS; do
    TARGET="${MOUNT_POINT}/${subpath}"
    if [ -d "$TARGET" ]; then
        echo "Deleting /$subpath ..."
        rm -rf "$TARGET"
        if [ $? -ne 0 ]; then
            echo "  WARNING: Failed to fully delete /$subpath"
            ALL_DELETE_OK=false
        else
            echo "  /$subpath  deleted"
        fi
    elif [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        echo "Deleting /$subpath (file/symlink)..."
        rm -f "$TARGET"
        if [ $? -ne 0 ]; then
            echo "  WARNING: Failed to delete /$subpath"
            ALL_DELETE_OK=false
        else
            echo "  /$subpath  deleted"
        fi
    else
        echo "  /$subpath  not found, skipping"
    fi
done

echo "========================================"
sync
sleep 1

# ============================================================
# [4/4] CREATE SYMLINK /userdata -> /sdcard
# ============================================================
echo ""
echo "[4/4] Creating symlink /userdata -> /sdcard ..."

SYMLINK_TARGET="${MOUNT_POINT}/userdata"
SYMLINK_POINT="/sdcard"

# Remove existing /userdata if it exists (dir, file, or old symlink)
if [ -e "$SYMLINK_TARGET" ] || [ -L "$SYMLINK_TARGET" ]; then
    echo "  Removing existing /userdata ..."
    rm -rf "$SYMLINK_TARGET"
    if [ $? -ne 0 ]; then
        echo "  WARNING: Could not remove existing /userdata"
    fi
fi

# Create the symlink
ln -s "$SYMLINK_POINT" "$SYMLINK_TARGET"
if [ $? -eq 0 ]; then
    echo "  Symlink created: /userdata -> /sdcard"
else
    echo "  ERROR: Failed to create symlink /userdata -> /sdcard"
fi

# Verify symlink
echo ""
echo "Verifying symlink:"
ls -la "${MOUNT_POINT}/userdata"

sync
sleep 1

# ============================================================
# FINAL VERIFICATION
# ============================================================
echo ""
echo "========================================"
echo "Final verification"
echo "========================================"
echo ""
echo "Partition root after cleanup:"
ls -la "$MOUNT_POINT"
echo ""
echo "Disk usage after cleanup:"
df -h "$MOUNT_POINT"

# ============================================================
# UNMOUNT
# ============================================================
echo ""
echo "Unmounting partition 77..."
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "WARNING: Could not unmount cleanly"
    umount -f "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT" 2>/dev/null

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================"
if [ "$ALL_DELETE_OK" = true ]; then
    echo "CLEANUP COMPLETED SUCCESSFULLY"
else
    echo "CLEANUP COMPLETED WITH WARNINGS"
fi
echo "========================================"
echo ""
echo "Actions performed on ${DEVICE}p77:"
echo ""
echo "Deleted paths:"
for dir in $DELETE_DIRS; do
    echo "  - /$dir"
done
for subpath in $DELETE_SUBPATHS; do
    echo "  - /$subpath"
done
echo ""
echo "Symlink created:"
echo "  /userdata -> /sdcard"
echo ""
echo "Done."