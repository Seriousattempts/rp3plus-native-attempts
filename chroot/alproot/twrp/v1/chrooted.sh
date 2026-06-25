#!/sbin/sh
#
# UMS512 - Combined Install Script
# Dynamically selects root and subfolder archives from SD card
# Supports: .tar.gz and .img (ext2/3/4 images mounted via loop)
# Preserves symlinks for both formats
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
MOUNT_POINT="/tmp/p77_mount"
TARLIST="${SD_CARD}/tarlist.txt"
SUBLIST="${SD_CARD}/sublist.txt"
SUMMARY_LOG="${SD_CARD}/install_summary.txt"
IMG_MOUNT="${SD_CARD}/img_loop_mount"

ROOT_RESULT=1
ALL_OK=true
ALL_DIRS_OK=true

echo "========================================"
echo "UMS512 Combined Installation Script"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Extract a selected archive to the partition root"
echo "3. Extract any additional archives each to their own named subfolder"
echo "   Supports: .tar.gz and .img (ext2/3/4)"
sleep 3

# ============================================================
# HELPER: get_type <filename>
# Outputs: "targz" or "img"
# ============================================================
get_type() {
    case "$1" in
        *.tar.gz) echo "targz" ;;
        *.img)    echo "img"   ;;
        *)        echo "unknown" ;;
    esac
}

# ============================================================
# HELPER: strip_ext <filename>
# Strips .tar.gz or .img to get bare name for subfolder
# ============================================================
strip_ext() {
    fname="$1"
    case "$fname" in
        *.tar.gz) echo "${fname%.tar.gz}" ;;
        *.img)    echo "${fname%.img}"    ;;
        *)        echo "$fname" ;;
    esac
}

# ============================================================
# HELPER: extract_archive <src> <dest>
# Handles both .tar.gz and .img, preserves symlinks
# Sets EXTRACT_RESULT variable
# ============================================================
extract_archive() {
    SRC="$1"
    DEST="$2"
    FNAME=$(basename "$SRC")
    FTYPE=$(get_type "$FNAME")
    EXTRACT_RESULT=1

    case "$FTYPE" in
        targz)
            tar -xpzf "$SRC" -C "$DEST" &
            TAR_PID=$!
            while kill -0 $TAR_PID 2>/dev/null; do
                sleep 10
                C=$(find "$DEST" -type f 2>/dev/null | wc -l)
                S=$(du -sh "$DEST" 2>/dev/null | awk '{print $1}')
                echo "  Progress: $C files, size: $S"
            done
            wait $TAR_PID
            EXTRACT_RESULT=$?
            ;;

        img)
            mkdir -p "$IMG_MOUNT" 2>/dev/null
            echo "  Mounting $FNAME via loop device..."
            mount -t ext4 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
            if [ $? -ne 0 ]; then
                # Try ext2/ext3 if ext4 fails
                mount -t ext2 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
                if [ $? -ne 0 ]; then
                    mount -t ext3 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
                    if [ $? -ne 0 ]; then
                        echo "  ERROR: Could not mount $FNAME as ext2/ext3/ext4"
                        rmdir "$IMG_MOUNT" 2>/dev/null
                        EXTRACT_RESULT=1
                        return
                    fi
                fi
            fi
            echo "  $FNAME mounted, copying with symlink preservation..."

            # Use rsync if available (best for symlinks), else cp -a
            if command -v rsync > /dev/null 2>&1; then
                rsync -aH --info=progress2 "$IMG_MOUNT/" "$DEST/"
                EXTRACT_RESULT=$?
            else
                (cd "$IMG_MOUNT" && cp -a . "$DEST/") &
                CP_PID=$!
                while kill -0 $CP_PID 2>/dev/null; do
                    sleep 10
                    C=$(find "$DEST" -type f 2>/dev/null | wc -l)
                    S=$(du -sh "$DEST" 2>/dev/null | awk '{print $1}')
                    echo "  Progress: $C files, size: $S"
                done
                wait $CP_PID
                EXTRACT_RESULT=$?
            fi

            echo "  Unmounting $FNAME..."
            umount "$IMG_MOUNT" 2>/dev/null
            rmdir "$IMG_MOUNT" 2>/dev/null
            ;;

        *)
            echo "  ERROR: Unknown file type for $FNAME"
            EXTRACT_RESULT=1
            ;;
    esac
}

# ============================================================
# [1/9] SCAN FOR .tar.gz AND .img FILES ON SD CARD
# ============================================================
echo ""
echo "[1/9] Scanning for .tar.gz and .img files on SD card..."

rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null

TAR_COUNT=0

for f in "${SD_CARD}"/*.tar.gz "${SD_CARD}"/*.img; do
    [ -f "$f" ] || continue
    TAR_COUNT=$((TAR_COUNT + 1))
    FNAME=$(basename "$f")
    FSIZE=$(ls -lh "$f" | awk '{print $5}')
    FTYPE=$(get_type "$FNAME")
    echo "  [$TAR_COUNT] $FNAME  ($FSIZE)  [${FTYPE}]"
    printf '%s|%s\n' "$TAR_COUNT" "$f" >> "$TARLIST"
done

if [ $TAR_COUNT -eq 0 ]; then
    echo "ERROR: No .tar.gz or .img files found in $SD_CARD"
    exit 1
fi
echo ""
echo "Found $TAR_COUNT archive(s) total."

# ============================================================
# [2/9] SELECT ROOT ARCHIVE
# ============================================================
echo ""
echo "[2/9] Select which file to extract to the partition root (/):"
echo "Enter a number (1-$TAR_COUNT):"

while true; do
    read ROOT_CHOICE
    VALID=false
    i=1
    while [ $i -le $TAR_COUNT ]; do
        [ "$ROOT_CHOICE" = "$i" ] && VALID=true && break
        i=$((i + 1))
    done
    [ "$VALID" = true ] && break
    echo "Invalid selection '$ROOT_CHOICE'. Enter a number between 1 and $TAR_COUNT:"
done

ROOT_SRC=$(awk -F'|' -v sel="$ROOT_CHOICE" '$1==sel {print $2}' "$TARLIST")
ROOT_NAME=$(basename "$ROOT_SRC")
ROOT_TYPE=$(get_type "$ROOT_NAME")
echo "Selected for root (/): $ROOT_NAME  [$ROOT_TYPE]"

# ============================================================
# [3/9] SELECT SUBFOLDER ARCHIVES
# ============================================================
echo ""
echo "[3/9] Remaining files available for subfolder extraction:"
echo "Each file will be extracted to its own subfolder at the partition root."
echo "(e.g. debian.tar.gz -> /debian,  vendor.img -> /vendor)"
echo ""

SUB_COUNT=0
while IFS='|' read -r idx fpath; do
    [ "$idx" = "$ROOT_CHOICE" ] && continue
    SUB_COUNT=$((SUB_COUNT + 1))
    FNAME=$(basename "$fpath")
    FSIZE=$(ls -lh "$fpath" | awk '{print $5}')
    FTYPE=$(get_type "$FNAME")
    SUB_DIR=$(strip_ext "$FNAME")
    echo "  [$SUB_COUNT] $FNAME  ($FSIZE)  [$FTYPE]  ->  /$SUB_DIR"
    printf '%s|%s\n' "$SUB_COUNT" "$fpath" >> "$SUBLIST"
done < "$TARLIST"

SUBFOLDERS_SELECTED=""

if [ $SUB_COUNT -eq 0 ]; then
    echo "  (No remaining files — only root will be extracted)"
else
    echo ""
    echo "Enter the numbers to extract as subfolders, separated by spaces"
    echo "(e.g.: 1 2 3), or press ENTER to skip:"

    while true; do
        read SUBFOLDER_INPUT
        if [ -z "$SUBFOLDER_INPUT" ]; then
            echo "No subfolder archives selected."
            SUBFOLDERS_SELECTED=""
            break
        fi
        ALL_NUMS_OK=true
        for num in $SUBFOLDER_INPUT; do
            FOUND=false
            i=1
            while [ $i -le $SUB_COUNT ]; do
                [ "$num" = "$i" ] && FOUND=true && break
                i=$((i + 1))
            done
            if [ "$FOUND" = false ]; then
                echo "Invalid number '$num'. Valid range is 1 to $SUB_COUNT. Re-enter all selections:"
                ALL_NUMS_OK=false
                break
            fi
        done
        if [ "$ALL_NUMS_OK" = true ]; then
            SUBFOLDERS_SELECTED="$SUBFOLDER_INPUT"
            break
        fi
    done
fi

# ============================================================
# CONFIRM PLAN
# ============================================================
echo ""
echo "========================================"
echo "Installation plan:"
echo "  Root (/):  $ROOT_NAME  [$ROOT_TYPE]"
if [ -n "$SUBFOLDERS_SELECTED" ]; then
    for num in $SUBFOLDERS_SELECTED; do
        SUB_PATH=$(awk -F'|' -v sel="$num" '$1==sel {print $2}' "$SUBLIST")
        SUB_FNAME=$(basename "$SUB_PATH")
        SUB_DIR=$(strip_ext "$SUB_FNAME")
        SUB_TYPE=$(get_type "$SUB_FNAME")
        echo "  /$SUB_DIR  <-  $SUB_FNAME  [$SUB_TYPE]"
    done
else
    echo "  Subfolders: none"
fi
echo "========================================"
echo ""
echo "WARNING: This will FORMAT partition 77 and DESTROY all existing data!"
echo "Type YES to continue or anything else to abort:"
read CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted. No changes made."
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 0
fi

# ============================================================
# [4/9] CHECK REQUIRED TOOLS
# ============================================================
echo ""
echo "[4/9] Checking required tools..."
MISSING_TOOLS=""
for tool in mke2fs mount dd tar; do
    ! command -v $tool > /dev/null 2>&1 && MISSING_TOOLS="${MISSING_TOOLS}$tool "
done
if [ -n "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools: $MISSING_TOOLS"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
echo "All required tools available"

if command -v rsync > /dev/null 2>&1; then
    echo "rsync available (used for .img loop copies)"
else
    echo "rsync not found - will use cp -a for .img copies"
fi

# ============================================================
# [5/9] UNMOUNT PARTITION 77 IF MOUNTED
# ============================================================
echo ""
echo "[5/9] Unmounting partition 77 if mounted..."
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        echo "ERROR: Could not unmount ${DEVICE}p${PARTITION_77}"
        rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
        exit 1
    fi
fi
echo "Partition 77 is not mounted"

# ============================================================
# [6/9] GET PARTITION SIZE
# ============================================================
echo ""
echo "[6/9] Getting partition size..."
PARTITION_SIZE=$(awk "/mmcblk0p${PARTITION_77}/{print \$3}" /proc/partitions)
if [ -z "$PARTITION_SIZE" ]; then
    echo "ERROR: Could not determine partition size"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
echo "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

# ============================================================
# [7/9] FORMAT PARTITION 77 AS EXT4
# ============================================================
echo ""
echo "[7/9] Formatting partition 77 as ext4..."
dd if=/dev/zero of=${DEVICE}p${PARTITION_77} bs=1M count=1 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Could not wipe partition header"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
mke2fs -F -t ext4 -b 4096 -L linuxdata ${DEVICE}p${PARTITION_77}
if [ $? -ne 0 ]; then
    echo "Trying alternative method..."
    mkfs.ext4 -F ${DEVICE}p${PARTITION_77}
    if [ $? -ne 0 ]; then
        echo "ERROR: Format failed"
        rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
        exit 1
    fi
fi
echo "ext4 filesystem created successfully"
sync
sleep 2

# ============================================================
# [8/9] MOUNT PARTITION 77
# ============================================================
echo ""
echo "[8/9] Mounting partition 77..."
mkdir -p "$MOUNT_POINT" 2>/dev/null
mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not mount partition 77"
    blkid ${DEVICE}p${PARTITION_77}
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
echo "Partition 77 mounted at $MOUNT_POINT"

# ============================================================
# [9/9] EXTRACT ALL ARCHIVES
# ============================================================
echo ""
echo "[9/9] Extracting archives..."

# --- ROOT EXTRACTION ---
echo ""
echo "========================================"
echo "Extracting: $ROOT_NAME  [$ROOT_TYPE]"
echo "Target:     / (partition root)"
echo "========================================"

extract_archive "$ROOT_SRC" "$MOUNT_POINT"
ROOT_RESULT=$EXTRACT_RESULT

if [ $ROOT_RESULT -ne 0 ]; then
    echo "WARNING: Root extraction reported errors (exit: $ROOT_RESULT)"
    ALL_OK=false
else
    echo "Root extraction completed"
fi

ROOT_FILE_COUNT=$(find "${MOUNT_POINT}" -maxdepth 5 -type f 2>/dev/null | wc -l)
ROOT_LINK_COUNT=$(find "${MOUNT_POINT}" -maxdepth 5 -type l 2>/dev/null | wc -l)
ROOT_SIZE=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}')
echo "Root: $ROOT_FILE_COUNT files, $ROOT_LINK_COUNT symlinks, $ROOT_SIZE"
printf 'ROOT|/|%s|%s|%s files|%s links|%s\n' \
    "$ROOT_NAME" "$ROOT_TYPE" "$ROOT_FILE_COUNT" "$ROOT_LINK_COUNT" "$ROOT_SIZE" >> "$SUMMARY_LOG"
sync

# --- SUBFOLDER EXTRACTIONS ---
if [ -n "$SUBFOLDERS_SELECTED" ]; then
    for num in $SUBFOLDERS_SELECTED; do
        SUB_PATH=$(awk -F'|' -v sel="$num" '$1==sel {print $2}' "$SUBLIST")
        SUB_FNAME=$(basename "$SUB_PATH")
        SUB_DIR=$(strip_ext "$SUB_FNAME")
        SUB_TYPE=$(get_type "$SUB_FNAME")
        SUB_DEST="${MOUNT_POINT}/${SUB_DIR}"

        echo ""
        echo "========================================"
        echo "Extracting: $SUB_FNAME  [$SUB_TYPE]"
        echo "Target:     /$SUB_DIR"
        echo "========================================"

        mkdir -p "$SUB_DEST" 2>/dev/null

        extract_archive "$SUB_PATH" "$SUB_DEST"
        SUB_RESULT=$EXTRACT_RESULT

        SUB_FC=$(find "$SUB_DEST" -type f 2>/dev/null | wc -l)
        SUB_LC=$(find "$SUB_DEST" -type l 2>/dev/null | wc -l)
        SUB_SZ=$(du -sh "$SUB_DEST" 2>/dev/null | awk '{print $1}')

        if [ $SUB_RESULT -ne 0 ]; then
            echo "WARNING: $SUB_FNAME extraction errors (exit: $SUB_RESULT)"
            ALL_OK=false
        else
            echo "$SUB_FNAME extraction completed"
        fi
        echo "  /$SUB_DIR: $SUB_FC files, $SUB_LC symlinks, $SUB_SZ"
        printf 'SUB|/%s|%s|%s|%s files|%s links|%s\n' \
            "$SUB_DIR" "$SUB_FNAME" "$SUB_TYPE" "$SUB_FC" "$SUB_LC" "$SUB_SZ" >> "$SUMMARY_LOG"
        sync
    done
fi

sleep 2

# ============================================================
# FINAL VERIFICATION
# ============================================================
echo ""
echo "========================================"
echo "Final verification"
echo "========================================"
echo ""

echo "Full partition root listing:"
ls -la "${MOUNT_POINT}"
echo ""

echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""

TOTAL_PARTITION_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
TOTAL_PARTITION_LINKS=$(find "${MOUNT_POINT}" -type l 2>/dev/null | wc -l)

echo "Verifying root directory structure..."
for dir in etc bin usr var home root; do
    if [ -d "${MOUNT_POINT}/$dir" ]; then
        echo "  /$dir  OK"
    else
        echo "  /$dir  MISSING"
        ALL_DIRS_OK=false
    fi
done

if [ -n "$SUBFOLDERS_SELECTED" ]; then
    echo ""
    echo "Verifying subfolder installations..."
    while IFS='|' read -r type target fname ftype fcount lcount fsize; do
        [ "$type" = "ROOT" ] && continue
        SUB_DIR=$(echo "$target" | sed 's|^/||')
        SUB_DEST="${MOUNT_POINT}/${SUB_DIR}"
        echo ""
        if [ -d "$SUB_DEST" ]; then
            echo "  $target  OK  ($fcount, $lcount, $fsize)  [$ftype]"
            echo "  $target contents:"
            ls -la "$SUB_DEST" | head -20
        else
            echo "  $target  MISSING"
            ALL_DIRS_OK=false
        fi
    done < "$SUMMARY_LOG"
fi

sync
sleep 2

echo ""
echo "Unmounting partition 77..."
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "WARNING: Could not unmount cleanly"
    umount -f "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT" 2>/dev/null
rm -f "$TARLIST" "$SUBLIST" 2>/dev/null

# ============================================================
# FINAL SUMMARY
# ============================================================
echo ""
echo "========================================"
if [ "$ALL_DIRS_OK" = true ] && [ "$ALL_OK" = true ]; then
    echo "COMBINED INSTALLATION COMPLETED SUCCESSFULLY"
else
    echo "COMBINED INSTALLATION COMPLETED WITH WARNINGS/ERRORS"
fi
echo "========================================"
echo ""
echo "Summary:"
echo "- Partition:  ${DEVICE}p77"
echo "- Filesystem: ext4"
while IFS='|' read -r type target fname ftype fcount lcount fsize; do
    if [ "$type" = "ROOT" ]; then
        echo "- Root /:     $fname  [$ftype]  ($fcount, $lcount, $fsize)"
    else
        echo "- $target:  $fname  [$ftype]  ($fcount, $lcount, $fsize)"
    fi
done < "$SUMMARY_LOG"
echo "- Total files on partition:   $TOTAL_PARTITION_FILES"
echo "- Total symlinks on partition: $TOTAL_PARTITION_LINKS"
echo ""
rm -f "$SUMMARY_LOG" 2>/dev/null
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