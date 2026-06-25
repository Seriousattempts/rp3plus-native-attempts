#!/sbin/sh
#
# UMS512 - Combined Install Script v3.3
# - Supports .tar.gz and .img archives
# - Optional super partition extraction (system_ext, vendor, product)
#   NOTE: system_a extraction removed. APEX extraction removed.
# - Preserves symlinks throughout
#
# Changes from v3.2:
#   - Removed system_a offset/extraction entirely
#   - Removed APEX extraction offer and logic
#   - Kept system_ext, vendor, product extraction unchanged
#

DEVICE="/dev/block/mmcblk0"
PARTITION_77=77
SD_CARD="/external_sd"
MOUNT_POINT="/tmp/p77_mount"
TARLIST="${SD_CARD}/tarlist.txt"
SUBLIST="${SD_CARD}/sublist.txt"
SUMMARY_LOG="${SD_CARD}/install_summary.txt"
IMG_MOUNT="/tmp/img_loop_mount"

# Super partition config
SUPER_PARTITION="/dev/block/mmcblk0p50"
SYSTEM_EXT_OFF_B=1379926016; SYSTEM_EXT_SZ_B=379461632
VENDOR_OFF_B=1759510528;     VENDOR_SZ_B=1894899712
PRODUCT_OFF_B=3655335936;    PRODUCT_SZ_B=609284096

# Super temp images staged on SD card (not /tmp) to avoid RAM exhaustion.
# vendor.img alone needs 1.76 GB - exceeds TWRP's RAM-backed tmpfs.
SUPER_IMG_DIR="${SD_CARD}/super_tmp"

ROOT_RESULT=1
ALL_OK=true
ALL_DIRS_OK=true
DO_SUPER=false

# ============================================================
# LOGGING HELPERS
# ============================================================
log_section() { echo ""; echo "========================================"; echo "  $1"; echo "========================================"; }
log_info()    { echo "  [INFO]  $1"; }
log_ok()      { echo "  [ OK ]  $1"; }
log_warn()    { echo "  [WARN]  $1"; }
log_err()     { echo "  [ERR ]  $1"; }

# ============================================================
# HELPER: get_type
# ============================================================
get_type() {
    case "$1" in
        *.tar.gz) echo "targz" ;;
        *.img)    echo "img"   ;;
        *)        echo "unknown" ;;
    esac
}

# ============================================================
# HELPER: strip_ext
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
                log_info "Progress: $C files, size: $S"
            done
            wait $TAR_PID
            EXTRACT_RESULT=$?
            ;;

        img)
            mkdir -p "$IMG_MOUNT" 2>/dev/null
            log_info "Mounting $FNAME via loop device..."
            mount -t ext4 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
            if [ $? -ne 0 ]; then
                mount -t ext2 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
                if [ $? -ne 0 ]; then
                    mount -t ext3 -o loop,ro "$SRC" "$IMG_MOUNT" 2>/dev/null
                    if [ $? -ne 0 ]; then
                        log_err "Could not mount $FNAME as ext2/ext3/ext4"
                        rmdir "$IMG_MOUNT" 2>/dev/null
                        EXTRACT_RESULT=1
                        return
                    fi
                fi
            fi
            log_info "$FNAME mounted, copying with symlink preservation..."
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
                    log_info "Progress: $C files, size: $S"
                done
                wait $CP_PID
                EXTRACT_RESULT=$?
            fi
            log_info "Unmounting $FNAME..."
            umount "$IMG_MOUNT" 2>/dev/null
            rmdir "$IMG_MOUNT" 2>/dev/null
            ;;

        *)
            log_err "Unknown file type for $FNAME"
            EXTRACT_RESULT=1
            ;;
    esac
}

# ============================================================
# HELPER: extract_super_part <label> <offset_b> <size_b> <dest>
#
# All super regions are 4096-byte aligned. bs=4096 is safe and ~8x
# faster than bs=512. Temp images go to SD card (not /tmp) because
# vendor is 1.76 GB - too large for TWRP's RAM-backed tmpfs.
# ============================================================
extract_super_part() {
    PART_LABEL="$1"
    OFFSET_B="$2"
    SIZE_B="$3"
    PART_DEST="$4"

    PART_IMG="${SUPER_IMG_DIR}/${PART_LABEL}.img"
    PART_MNT="/tmp/${PART_LABEL}_mnt"

    SKIP_BLOCKS=$(awk "BEGIN {printf \"%.0f\", $OFFSET_B / 4096}")
    COUNT_BLOCKS=$(awk "BEGIN {printf \"%.0f\", $SIZE_B / 4096}")

    log_info "dd: $SUPER_PARTITION -> $PART_IMG"
    log_info "    bs=4096  skip=$SKIP_BLOCKS  count=$COUNT_BLOCKS"
    log_info "    (~$(awk "BEGIN {printf \"%.0f\", $SIZE_B / 1048576}") MB staged on SD card)"

    mkdir -p "$SUPER_IMG_DIR" 2>/dev/null

    dd if="$SUPER_PARTITION" of="$PART_IMG" bs=4096 \
        skip=$SKIP_BLOCKS count=$COUNT_BLOCKS 2>/dev/null
    if [ $? -ne 0 ]; then
        log_err "dd failed for $PART_LABEL"
        rm -f "$PART_IMG" 2>/dev/null
        return 1
    fi

    log_info "$PART_LABEL image staged, mounting..."
    mkdir -p "$PART_MNT" 2>/dev/null

    mount -t ext4 -o ro "$PART_IMG" "$PART_MNT" 2>/dev/null
    if [ $? -ne 0 ]; then
        mount -t erofs -o ro "$PART_IMG" "$PART_MNT" 2>/dev/null
        if [ $? -ne 0 ]; then
            mount -t ext2 -o ro "$PART_IMG" "$PART_MNT" 2>/dev/null
            if [ $? -ne 0 ]; then
                log_err "Could not mount $PART_LABEL image (ext4/erofs/ext2 all failed)"
                rm -f "$PART_IMG"
                rmdir "$PART_MNT" 2>/dev/null
                return 1
            fi
        fi
    fi

    log_info "$PART_LABEL mounted at $PART_MNT, copying to $PART_DEST..."
    mkdir -p "$PART_DEST" 2>/dev/null

    if command -v rsync > /dev/null 2>&1; then
        rsync -aH "$PART_MNT/" "$PART_DEST/"
        COPY_RC=$?
    else
        (cd "$PART_MNT" && cp -a . "$PART_DEST/")
        COPY_RC=$?
    fi

    umount "$PART_MNT" 2>/dev/null
    rmdir "$PART_MNT" 2>/dev/null
    rm -f "$PART_IMG" 2>/dev/null

    if [ $COPY_RC -eq 0 ]; then
        FC=$(find "$PART_DEST" -type f 2>/dev/null | wc -l)
        LC=$(find "$PART_DEST" -type l 2>/dev/null | wc -l)
        SZ=$(du -sh "$PART_DEST" 2>/dev/null | awk '{print $1}')
        log_ok "$PART_LABEL -> $PART_DEST  ($FC files, $LC symlinks, $SZ)"
        return 0
    else
        log_err "Copy failed for $PART_LABEL"
        return 1
    fi
}

# ============================================================
# HEADER
# ============================================================
echo "========================================"
echo "UMS512 Combined Installation Script v3.3"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Format partition 77 as ext4"
echo "2. Extract a selected archive to the partition root"
echo "3. Extract any additional archives each to their own named subfolder"
echo "4. Optionally extract super partitions (system_ext, vendor, product)"
echo "   Supports: .tar.gz and .img (ext2/3/4)"
sleep 3

# ============================================================
# [1/9] SCAN FOR .tar.gz AND .img FILES ON SD CARD
# ============================================================
log_section "[1/9] Scanning for archives on SD card"

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
    log_err "No .tar.gz or .img files found in $SD_CARD"
    exit 1
fi
echo ""
log_info "Found $TAR_COUNT archive(s) total."

# ============================================================
# [2/9] SELECT ROOT ARCHIVE
# ============================================================
log_section "[2/9] Select root archive"
echo "Select which file to extract to the partition root (/):"
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
log_ok "Selected for root (/): $ROOT_NAME  [$ROOT_TYPE]"

# ============================================================
# [3/9] SELECT SUBFOLDER ARCHIVES
# ============================================================
log_section "[3/9] Select subfolder archives"
echo "Remaining files available for subfolder extraction."
echo "Each file extracts to its own named subfolder at partition root."
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
    echo "  (No remaining files - only root will be extracted)"
else
    echo ""
    echo "Enter numbers to extract as subfolders, space-separated (e.g.: 1 2 3)"
    echo "or press ENTER to skip:"
    while true; do
        read SUBFOLDER_INPUT
        if [ -z "$SUBFOLDER_INPUT" ]; then
            log_info "No subfolder archives selected."
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
# SUPER PARTITION EXTRACTION OFFER
# ============================================================
log_section "Super Partition Extraction"
echo "Do you want to extract partitions from the super partition?"
echo "This will extract the following into partition 77:"
echo ""
echo "  system_ext -> /system_ext"
echo "  vendor     -> /vendor"
echo "  product    -> /product"
echo ""
echo "  Source: $SUPER_PARTITION"
echo "  Temp images staged on: $SUPER_IMG_DIR (SD card)"
echo ""
echo "  Press 1 = NO  (skip super extraction)"
echo "  Press 2 = YES (extract super partitions)"
echo ""

while true; do
    read SUPER_CHOICE
    case "$SUPER_CHOICE" in
        1) DO_SUPER=false; log_info "Skipping super partition extraction."; break ;;
        2) DO_SUPER=true;  log_ok "Super partition extraction selected."; break ;;
        *) echo "Invalid choice. Press 1 (NO) or 2 (YES):" ;;
    esac
done

# ============================================================
# CONFIRM PLAN
# ============================================================
log_section "Installation Plan"
echo "  Root (/):     $ROOT_NAME  [$ROOT_TYPE]"
if [ -n "$SUBFOLDERS_SELECTED" ]; then
    for num in $SUBFOLDERS_SELECTED; do
        SUB_PATH=$(awk -F'|' -v sel="$num" '$1==sel {print $2}' "$SUBLIST")
        SUB_FNAME=$(basename "$SUB_PATH")
        SUB_DIR=$(strip_ext "$SUB_FNAME")
        SUB_TYPE=$(get_type "$SUB_FNAME")
        echo "  /$SUB_DIR  <-  $SUB_FNAME  [$SUB_TYPE]"
    done
else
    echo "  Subfolders:   none"
fi
if [ "$DO_SUPER" = true ]; then
    echo "  Super parts:  system_ext -> /system_ext"
    echo "                vendor     -> /vendor"
    echo "                product    -> /product"
    echo "                (staged on SD card, not RAM)"
else
    echo "  Super parts:  skipped"
fi
echo ""
echo "WARNING: This will FORMAT partition 77 and DESTROY all existing data!"
echo ""
echo "  Press 1 = NO  (abort, make no changes)"
echo "  Press 2 = YES (proceed with installation)"
echo ""

while true; do
    read CONFIRM_CHOICE
    case "$CONFIRM_CHOICE" in
        1)
            log_info "Aborted. No changes made."
            rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
            exit 0
            ;;
        2)
            log_ok "Confirmed. Proceeding..."
            break
            ;;
        *) echo "Invalid choice. Press 1 (NO) or 2 (YES):" ;;
    esac
done

# ============================================================
# [4/9] CHECK REQUIRED TOOLS
# ============================================================
log_section "[4/9] Checking required tools"
MISSING_TOOLS=""
for tool in mke2fs mount dd tar awk; do
    ! command -v $tool > /dev/null 2>&1 && MISSING_TOOLS="${MISSING_TOOLS}$tool "
done
if [ -n "$MISSING_TOOLS" ]; then
    log_err "Missing required tools: $MISSING_TOOLS"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
log_ok "All required tools available"

if command -v rsync > /dev/null 2>&1; then
    log_ok "rsync available (preferred for symlink-safe copies)"
else
    log_warn "rsync not found - will use cp -a"
fi

# ============================================================
# [5/9] UNMOUNT PARTITION 77 IF MOUNTED
# ============================================================
log_section "[5/9] Unmounting partition 77 if mounted"
if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
    umount ${DEVICE}p${PARTITION_77} 2>/dev/null || umount -f ${DEVICE}p${PARTITION_77} 2>/dev/null
    if mount | grep -q "${DEVICE}p${PARTITION_77}"; then
        log_err "Could not unmount ${DEVICE}p${PARTITION_77}"
        rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
        exit 1
    fi
fi
log_ok "Partition 77 is not mounted"

# ============================================================
# [6/9] GET PARTITION SIZE
# ============================================================
log_section "[6/9] Getting partition size"
PARTITION_SIZE=$(awk "/mmcblk0p${PARTITION_77}/{print \$3}" /proc/partitions)
if [ -z "$PARTITION_SIZE" ]; then
    log_err "Could not determine partition size"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
PARTITION_SIZE_MB=$((PARTITION_SIZE / 1024))
log_ok "Partition 77 size: $PARTITION_SIZE blocks (~${PARTITION_SIZE_MB} MB)"

# ============================================================
# [7/9] FORMAT PARTITION 77 AS EXT4
# ============================================================
log_section "[7/9] Formatting partition 77 as ext4"
dd if=/dev/zero of=${DEVICE}p${PARTITION_77} bs=1M count=1 2>/dev/null
if [ $? -ne 0 ]; then
    log_err "Could not wipe partition header"
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
mke2fs -F -t ext4 -b 4096 -L linuxdata ${DEVICE}p${PARTITION_77}
if [ $? -ne 0 ]; then
    log_warn "mke2fs failed, trying mkfs.ext4..."
    mkfs.ext4 -F ${DEVICE}p${PARTITION_77}
    if [ $? -ne 0 ]; then
        log_err "Format failed"
        rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
        exit 1
    fi
fi
log_ok "ext4 filesystem created successfully"
sync
sleep 2

# ============================================================
# [8/9] MOUNT PARTITION 77
# ============================================================
log_section "[8/9] Mounting partition 77"
mkdir -p "$MOUNT_POINT" 2>/dev/null
mount -t ext4 ${DEVICE}p${PARTITION_77} "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    log_err "Could not mount partition 77"
    blkid ${DEVICE}p${PARTITION_77}
    rm -f "$TARLIST" "$SUBLIST" "$SUMMARY_LOG" 2>/dev/null
    exit 1
fi
log_ok "Partition 77 mounted at $MOUNT_POINT"

# ============================================================
# [9/9] EXTRACT ALL ARCHIVES
# ============================================================
log_section "[9/9] Extracting archives"

# --- ROOT EXTRACTION ---
log_section "Extracting: $ROOT_NAME  [$ROOT_TYPE] -> / (partition root)"

extract_archive "$ROOT_SRC" "$MOUNT_POINT"
ROOT_RESULT=$EXTRACT_RESULT

if [ $ROOT_RESULT -ne 0 ]; then
    log_warn "Root extraction reported errors (exit: $ROOT_RESULT)"
    ALL_OK=false
else
    log_ok "Root extraction completed"
fi
ROOT_FILE_COUNT=$(find "${MOUNT_POINT}" -maxdepth 5 -type f 2>/dev/null | wc -l)
ROOT_LINK_COUNT=$(find "${MOUNT_POINT}" -maxdepth 5 -type l 2>/dev/null | wc -l)
ROOT_SIZE=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}')
log_info "Root: $ROOT_FILE_COUNT files, $ROOT_LINK_COUNT symlinks, $ROOT_SIZE"
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

        log_section "Extracting: $SUB_FNAME  [$SUB_TYPE] -> /$SUB_DIR"
        mkdir -p "$SUB_DEST" 2>/dev/null
        extract_archive "$SUB_PATH" "$SUB_DEST"
        SUB_RESULT=$EXTRACT_RESULT

        SUB_FC=$(find "$SUB_DEST" -type f 2>/dev/null | wc -l)
        SUB_LC=$(find "$SUB_DEST" -type l 2>/dev/null | wc -l)
        SUB_SZ=$(du -sh "$SUB_DEST" 2>/dev/null | awk '{print $1}')

        if [ $SUB_RESULT -ne 0 ]; then
            log_warn "$SUB_FNAME extraction errors (exit: $SUB_RESULT)"
            ALL_OK=false
        else
            log_ok "$SUB_FNAME extraction completed"
        fi
        log_info "  /$SUB_DIR: $SUB_FC files, $SUB_LC symlinks, $SUB_SZ"
        printf 'SUB|/%s|%s|%s|%s files|%s links|%s\n' \
            "$SUB_DIR" "$SUB_FNAME" "$SUB_TYPE" "$SUB_FC" "$SUB_LC" "$SUB_SZ" >> "$SUMMARY_LOG"
        sync
    done
fi

# ============================================================
# SUPER PARTITION EXTRACTION
# ============================================================
if [ "$DO_SUPER" = true ]; then
    log_section "Super Partition Extraction"

    if [ ! -b "$SUPER_PARTITION" ]; then
        log_err "$SUPER_PARTITION not found as block device - skipping"
        ALL_OK=false
    else
        log_info "Source: $SUPER_PARTITION"
        log_info "Staging temp images at: $SUPER_IMG_DIR"
        mkdir -p "$SUPER_IMG_DIR" 2>/dev/null

        # Check SD card free space against vendor (largest partition)
        SD_FREE_KB=$(df "$SD_CARD" 2>/dev/null | awk 'NR==2 {print $4}')
        VENDOR_NEED_KB=$(awk "BEGIN {printf \"%.0f\", $VENDOR_SZ_B / 1024}")
        if [ -n "$SD_FREE_KB" ]; then
            if awk "BEGIN {exit !($SD_FREE_KB < $VENDOR_NEED_KB)}"; then
                log_warn "SD card may not have enough space for vendor image"
                log_warn "  Available: ${SD_FREE_KB} KB, needed: ${VENDOR_NEED_KB} KB"
            else
                log_ok "SD card has sufficient free space for staging"
            fi
        fi

        # --- system_ext -> /system_ext ---
        log_section "Extracting system_ext -> /system_ext"
        extract_super_part "system_ext" "$SYSTEM_EXT_OFF_B" "$SYSTEM_EXT_SZ_B" \
            "${MOUNT_POINT}/system_ext"
        if [ $? -eq 0 ]; then
            SE_FC=$(find "${MOUNT_POINT}/system_ext" -type f 2>/dev/null | wc -l)
            SE_LC=$(find "${MOUNT_POINT}/system_ext" -type l 2>/dev/null | wc -l)
            SE_SZ=$(du -sh "${MOUNT_POINT}/system_ext" 2>/dev/null | awk '{print $1}')
            printf 'SUPER|/system_ext|system_ext|img|%s files|%s links|%s\n' \
                "$SE_FC" "$SE_LC" "$SE_SZ" >> "$SUMMARY_LOG"
        else
            ALL_OK=false
        fi
        sync

        # --- vendor -> /vendor ---
        log_section "Extracting vendor -> /vendor"
        extract_super_part "vendor" "$VENDOR_OFF_B" "$VENDOR_SZ_B" \
            "${MOUNT_POINT}/vendor"
        if [ $? -eq 0 ]; then
            V_FC=$(find "${MOUNT_POINT}/vendor" -type f 2>/dev/null | wc -l)
            V_LC=$(find "${MOUNT_POINT}/vendor" -type l 2>/dev/null | wc -l)
            V_SZ=$(du -sh "${MOUNT_POINT}/vendor" 2>/dev/null | awk '{print $1}')
            printf 'SUPER|/vendor|vendor|img|%s files|%s links|%s\n' \
                "$V_FC" "$V_LC" "$V_SZ" >> "$SUMMARY_LOG"
        else
            ALL_OK=false
        fi
        sync

        # --- product -> /product ---
        log_section "Extracting product -> /product"
        extract_super_part "product" "$PRODUCT_OFF_B" "$PRODUCT_SZ_B" \
            "${MOUNT_POINT}/product"
        if [ $? -eq 0 ]; then
            P_FC=$(find "${MOUNT_POINT}/product" -type f 2>/dev/null | wc -l)
            P_LC=$(find "${MOUNT_POINT}/product" -type l 2>/dev/null | wc -l)
            P_SZ=$(du -sh "${MOUNT_POINT}/product" 2>/dev/null | awk '{print $1}')
            printf 'SUPER|/product|product|img|%s files|%s links|%s\n' \
                "$P_FC" "$P_LC" "$P_SZ" >> "$SUMMARY_LOG"
        else
            ALL_OK=false
        fi
        sync

        # Clean up staging dir
        rm -rf "$SUPER_IMG_DIR" 2>/dev/null
    fi
fi

sleep 2

# ============================================================
# FINAL VERIFICATION
# ============================================================
log_section "Final Verification"

echo "Partition root listing:"
ls -la "${MOUNT_POINT}"
echo ""
echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""

TOTAL_PARTITION_FILES=$(find "${MOUNT_POINT}" -type f 2>/dev/null | wc -l)
TOTAL_PARTITION_LINKS=$(find "${MOUNT_POINT}" -type l 2>/dev/null | wc -l)

log_info "Verifying root directory structure..."
for dir in etc bin usr var home root; do
    if [ -d "${MOUNT_POINT}/$dir" ]; then
        log_ok "/$dir  present"
    else
        log_warn "/$dir  MISSING"
        ALL_DIRS_OK=false
    fi
done

if [ -n "$SUBFOLDERS_SELECTED" ] || [ "$DO_SUPER" = true ]; then
    echo ""
    log_info "Verifying subfolder/super installations..."
    while IFS='|' read -r type target fname ftype fcount lcount fsize; do
        [ "$type" = "ROOT" ] && continue
        target_dir=$(echo "$target" | sed 's|^/||')
        TARGET_PATH="${MOUNT_POINT}/${target_dir}"
        if [ -d "$TARGET_PATH" ]; then
            log_ok "$target  ($fcount, $lcount, $fsize)  [$ftype]"
        else
            log_warn "$target  MISSING"
            ALL_DIRS_OK=false
        fi
    done < "$SUMMARY_LOG"
fi

sync
sleep 2

log_info "Unmounting partition 77..."
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    log_warn "Could not unmount cleanly"
    umount -f "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT" 2>/dev/null
rm -f "$TARLIST" "$SUBLIST" 2>/dev/null

# ============================================================
# FINAL SUMMARY
# ============================================================
log_section "Installation Summary"
if [ "$ALL_DIRS_OK" = true ] && [ "$ALL_OK" = true ]; then
    echo "  STATUS: COMPLETED SUCCESSFULLY"
else
    echo "  STATUS: COMPLETED WITH WARNINGS/ERRORS"
fi
echo ""
echo "  Partition:  ${DEVICE}p77"
echo "  Filesystem: ext4"
echo ""
while IFS='|' read -r type target fname ftype fcount lcount fsize; do
    case "$type" in
        ROOT)  echo "  Root /:       $fname  [$ftype]  ($fcount, $lcount, $fsize)" ;;
        SUB)   echo "  $target:  $fname  [$ftype]  ($fcount, $lcount, $fsize)" ;;
        SUPER) echo "  Super $target:  ($fcount, $lcount, $fsize)" ;;
    esac
done < "$SUMMARY_LOG"
echo ""
echo "  Total files on partition:    $TOTAL_PARTITION_FILES"
echo "  Total symlinks on partition: $TOTAL_PARTITION_LINKS"
echo ""
rm -f "$SUMMARY_LOG" 2>/dev/null
echo "========================================"
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