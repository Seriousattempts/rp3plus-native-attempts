#!/sbin/sh
#
# UMS512 File Management Script for Partition 77
# Deletes specified files/folders and moves multiple files from SD card
# Automatically detects numbered variables (DELETE_PATH_1, DELETE_PATH_2, etc.)
#

# ====================================
# CONFIGURABLE VARIABLES - EDIT HERE
# ====================================

# Partition settings
DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
MOUNT_POINT="/tmp/p77_mount"

# Paths to delete (files OR directories)
DELETE_PATH_1="/chroot-distro"
DELETE_PATH_2="/root/dev-nodes.sh"
# DELETE_PATH_3="/root/dev-nodes.sh"
# DELETE_PATH_4="/var/lib/lxc/android:
# DELETE_PATH_5="/android/system_ext"

# Source files on SD card and their destination paths
# SOURCE_FILE_1="/external_sd/Vendor_2022_Product_3001.zip"
# DEST_PATH_1="/etc/Vendor_2022_Product_3001.zip"

# More pairs by incrementing the number:
# SOURCE_FILE_2="/external_sd/hybrislinks"
# DEST_PATH_2="/etc/init.d/hybrislinks"

# Even More pairs by incrementing the number:
# SOURCE_FILE_3="/external_sd/setup-unisoc-hardware"
# DEST_PATH_3="/usr/local/bin/setup-unisoc-hardware"

# Even More pairs by incrementing the number:
# SOURCE_FILE_4="/external_sd/ld.so.conf"
# DEST_PATH_4="/etc/ld.so.conf"

# ====================================
# END CONFIGURATION
# ====================================

echo "========================================"
echo "UMS512 File Management Script"
echo "Partition 77 File Operations"
echo "========================================"

# Function to count how many DELETE_PATH_* variables exist
count_delete_paths() {
    local count=0
    local i=1
    while true; do
        eval "local var=\$DELETE_PATH_${i}"
        if [ -z "$var" ]; then
            break
        fi
        count=$((count + 1))
        i=$((i + 1))
    done
    echo $count
}

# Function to count how many SOURCE_FILE_* variables exist
count_source_files() {
    local count=0
    local i=1
    while true; do
        eval "local var=\$SOURCE_FILE_${i}"
        if [ -z "$var" ]; then
            break
        fi
        count=$((count + 1))
        i=$((i + 1))
    done
    echo $count
}

# Count operations
DELETE_COUNT=$(count_delete_paths)
SOURCE_COUNT=$(count_source_files)

echo ""
echo "This script will:"
echo "1. Mount partition 77"
echo "2. Delete $DELETE_COUNT path(s) (files/folders)"
echo "3. Move $SOURCE_COUNT file(s) from SD card to partition"
echo ""

# List delete operations
if [ $DELETE_COUNT -gt 0 ]; then
    echo "Paths to delete:"
    i=1
    while [ $i -le $DELETE_COUNT ]; do
        eval "path=\$DELETE_PATH_${i}"
        echo "  - $path"
        i=$((i + 1))
    done
    echo ""
fi

# List move operations
if [ $SOURCE_COUNT -gt 0 ]; then
    echo "Files to move:"
    i=1
    while [ $i -le $SOURCE_COUNT ]; do
        eval "src=\$SOURCE_FILE_${i}"
        eval "dst=\$DEST_PATH_${i}"
        echo "  - $src → $dst"
        i=$((i + 1))
    done
    echo ""
fi

sleep 3

echo ""
echo "[1/6] Checking if all source files exist..."
ALL_SOURCES_EXIST=true
i=1
while [ $i -le $SOURCE_COUNT ]; do
    eval "src=\$SOURCE_FILE_${i}"
    if [ ! -f "$src" ]; then
        echo "✗ ERROR: $src not found!"
        ALL_SOURCES_EXIST=false
    else
        FILE_SIZE=$(ls -lh "$src" | awk '{print $5}')
        echo "✓ Found: $src ($FILE_SIZE)"
    fi
    i=$((i + 1))
done

if [ "$ALL_SOURCES_EXIST" = false ]; then
    echo ""
    echo "ERROR: One or more source files are missing"
    echo "Available files in /external_sd:"
    ls -lh /external_sd/ 2>/dev/null || echo "Cannot list /external_sd"
    exit 1
fi

echo ""
echo "[2/6] Checking if partition 77 exists..."
if [ ! -b "${DEVICE}p${PARTITION_77}" ]; then
    echo "ERROR: ${DEVICE}p${PARTITION_77} does not exist!"
    echo "Available partitions:"
    ls -la ${DEVICE}p* | grep -E "(76|77|78)"
    exit 1
fi
echo "✓ Partition 77 exists: ${DEVICE}p${PARTITION_77}"

echo ""
echo "[3/6] Mounting partition 77..."
mkdir -p "$MOUNT_POINT" 2>/dev/null

# Unmount if already mounted
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    echo "Partition already mounted, unmounting first..."
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
fi

mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    echo "Partition info:"
    blkid ${DEVICE}p${PARTITION_77}
    exit 1
fi
echo "✓ Partition 77 mounted at $MOUNT_POINT"

echo ""
echo "[4/6] Deleting specified paths (files/directories)..."

if [ $DELETE_COUNT -eq 0 ]; then
    echo "No paths to delete (skipping)"
else
    DELETED_COUNT=0
    SKIPPED_COUNT=0
    
    i=1
    while [ $i -le $DELETE_COUNT ]; do
        eval "del_path=\$DELETE_PATH_${i}"
        FULL_DELETE="${MOUNT_POINT}${del_path}"
        
        # Check if it's a file
        if [ -f "$FULL_DELETE" ]; then
            echo "Deleting file [$i/$DELETE_COUNT]: $del_path"
            rm -f "$FULL_DELETE"
            if [ $? -eq 0 ]; then
                echo "  ✓ File deleted successfully"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                echo "  ⚠ WARNING: Could not delete file"
            fi
        # Check if it's a directory
        elif [ -d "$FULL_DELETE" ]; then
            echo "Deleting directory [$i/$DELETE_COUNT]: $del_path"
            
            # Check if it's a symlink first
            if [ -L "$FULL_DELETE" ]; then
                echo "  (This is a symlink)"
                rm -f "$FULL_DELETE"
                if [ $? -eq 0 ]; then
                    echo "  ✓ Symlink deleted successfully"
                    DELETED_COUNT=$((DELETED_COUNT + 1))
                else
                    echo "  ⚠ WARNING: Could not delete symlink"
                fi
            else
                # Get directory size before deletion
                DIR_SIZE=$(du -sh "$FULL_DELETE" 2>/dev/null | awk '{print $1}')
                FILE_COUNT=$(find "$FULL_DELETE" -type f 2>/dev/null | wc -l)
                echo "  Directory contains: $FILE_COUNT files ($DIR_SIZE)"
                
                rm -rf "$FULL_DELETE"
                if [ $? -eq 0 ]; then
                    echo "  ✓ Directory deleted successfully"
                    DELETED_COUNT=$((DELETED_COUNT + 1))
                else
                    echo "  ⚠ WARNING: Could not delete directory"
                fi
            fi
        else
            echo "Skipping [$i/$DELETE_COUNT]: $del_path (does not exist)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
        
        i=$((i + 1))
    done
    
    echo ""
    echo "Deletion summary: $DELETED_COUNT deleted, $SKIPPED_COUNT skipped"
fi

sync

echo ""
echo "[5/6] Moving files from SD card to partition..."

if [ $SOURCE_COUNT -eq 0 ]; then
    echo "No files to move (skipping)"
else
    MOVED_COUNT=0
    
    i=1
    while [ $i -le $SOURCE_COUNT ]; do
        eval "src=\$SOURCE_FILE_${i}"
        eval "dst=\$DEST_PATH_${i}"
        FULL_DEST="${MOUNT_POINT}${dst}"
        
        echo ""
        echo "Processing file [$i/$SOURCE_COUNT]:"
        echo "  Source: $src"
        echo "  Destination: $dst"
        
        # Create destination directory if it doesn't exist
        DEST_DIR=$(dirname "$FULL_DEST")
        if [ ! -d "$DEST_DIR" ]; then
            echo "  Creating destination directory..."
            mkdir -p "$DEST_DIR"
            if [ $? -ne 0 ]; then
                echo "  ✗ ERROR: Could not create destination directory"
                continue
            fi
        fi
        
        # Move the file
        mv "$src" "$FULL_DEST"
        if [ $? -eq 0 ]; then
            echo "  ✓ File moved successfully"
            
            # Verify the file exists at destination
            if [ -f "$FULL_DEST" ]; then
                NEW_SIZE=$(ls -lh "$FULL_DEST" | awk '{print $5}')
                echo "  ✓ Verified at destination ($NEW_SIZE)"
                
                # Set appropriate permissions
                chmod 755 "$FULL_DEST" 2>/dev/null
                
                MOVED_COUNT=$((MOVED_COUNT + 1))
            else
                echo "  ⚠ WARNING: Move reported success but file not found"
            fi
        else
            echo "  ✗ ERROR: Could not move file"
        fi
        
        i=$((i + 1))
    done
    
    echo ""
    echo "Move summary: $MOVED_COUNT/$SOURCE_COUNT files moved successfully"
fi

sync
sleep 1

echo ""
echo "[6/6] Final verification and cleanup..."

# Verify moved files
if [ $SOURCE_COUNT -gt 0 ]; then
    echo ""
    echo "Verifying moved files:"
    i=1
    while [ $i -le $SOURCE_COUNT ]; do
        eval "dst=\$DEST_PATH_${i}"
        FULL_DEST="${MOUNT_POINT}${dst}"
        
        if [ -f "$FULL_DEST" ]; then
            SIZE=$(ls -lh "$FULL_DEST" | awk '{print $5}')
            echo "  ✓ $dst ($SIZE)"
        else
            echo "  ✗ $dst (NOT FOUND)"
        fi
        
        i=$((i + 1))
    done
fi

# Verify deleted paths are gone
if [ $DELETE_COUNT -gt 0 ]; then
    echo ""
    echo "Verifying deletions:"
    i=1
    while [ $i -le $DELETE_COUNT ]; do
        eval "del_path=\$DELETE_PATH_${i}"
        FULL_DELETE="${MOUNT_POINT}${del_path}"
        
        if [ -e "$FULL_DELETE" ]; then
            echo "  ⚠ $del_path (STILL EXISTS)"
        else
            echo "  ✓ $del_path (deleted)"
        fi
        
        i=$((i + 1))
    done
fi

echo ""
echo "Disk usage:"
df -h "$MOUNT_POINT"

sync
sleep 1

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
echo "✓ FILE OPERATIONS COMPLETED"
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition: ${DEVICE}p${PARTITION_77}"
echo "- Paths deleted: $DELETED_COUNT/$DELETE_COUNT"
echo "- Files moved: $MOVED_COUNT/$SOURCE_COUNT"
echo ""
echo "Operations complete. You may now proceed with your next steps."
