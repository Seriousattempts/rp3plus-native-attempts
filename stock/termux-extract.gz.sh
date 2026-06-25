#!/data/data/com.termux/files/usr/bin/bash

# Backup Complete Termux Environment to tar.gz
# Preserves symlinks, permissions, and all file attributes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Canonical Termux base path
TERMUX_FILES="/data/data/com.termux/files"

detect_sdcard_path() {
    printf "${BLUE}=== Auto-detecting SD card path ===${NC}\n"
    SDCARD_PATH=$(ls -d /storage/*-* 2>/dev/null | head -1)
    if [ -z "$SDCARD_PATH" ]; then
        for path in "/storage/emulated/0" "/sdcard" "/storage/sdcard1"; do
            if [ -d "$path" ] && [ -w "$path" ]; then
                SDCARD_PATH="$path"
                break
            fi
        done
    fi
    if [ -z "$SDCARD_PATH" ]; then
        printf "${RED}ERROR: Could not auto-detect SD card path.${NC}\n"
        return 1
    else
        printf "${GREEN}✓ Detected SD card path: $SDCARD_PATH${NC}\n"
        return 0
    fi
}

validate_termux_env() {
    printf "${BLUE}=== Validating Termux Environment ===${NC}\n"
    
    if [ ! -d "$TERMUX_FILES/usr" ] || [ ! -d "$TERMUX_FILES/home" ]; then
        printf "${RED}ERROR: Standard Termux system files not found at $TERMUX_FILES${NC}\n"
        return 1
    fi
    
    printf "${GREEN}✓ Termux base folder verified: $TERMUX_FILES${NC}\n"
    
    # Show top level items
    printf "\nTop-level folders to pack:\n"
    printf "- home/ (User files and settings)\n"
    printf "- usr/  (Binaries, packages, and libraries)\n"
    
    # Count items inside home and usr
    printf "\nCounting files and directories...\n"
    TOTAL_FILES=$(find "$TERMUX_FILES/home" "$TERMUX_FILES/usr" -type f 2>/dev/null | wc -l)
    TOTAL_DIRS=$(find "$TERMUX_FILES/home" "$TERMUX_FILES/usr" -type d 2>/dev/null | wc -l)
    TOTAL_LINKS=$(find "$TERMUX_FILES/home" "$TERMUX_FILES/usr" -type l 2>/dev/null | wc -l)
    
    printf "Files: $TOTAL_FILES\n"
    printf "Directories: $TOTAL_DIRS\n"
    printf "Symlinks: $TOTAL_LINKS\n"
    
    return 0
}

check_space() {
    printf "\n${BLUE}=== Space Check ===${NC}\n"
    
    printf "Calculating Termux system size...\n"
    # du commands targeting home and usr explicitly
    USED_SPACE=$(du -sh "$TERMUX_FILES/home" "$TERMUX_FILES/usr" 2>/dev/null | awk '{sum+=$1} END {print sum "MB"}')
    USED_KB=$(du -sk "$TERMUX_FILES/home" "$TERMUX_FILES/usr" 2>/dev/null | awk '{sum+=$1} END {print sum}')
    USED_MB=$((USED_KB / 1024))
    
    printf "Total Termux size: ~${USED_MB} MB\n"
    
    # Estimate compressed size (usually 30-50% of original)
    EST_COMPRESSED_MB=$((USED_MB / 2))
    printf "Estimated tar.gz size: ~${EST_COMPRESSED_MB} MB\n"
    
    SD_FREE=$(df -k "$SDCARD_PATH" | tail -1 | awk '{print $4}')
    SD_FREE_MB=$((SD_FREE / 1024))
    printf "SD card available: ${SD_FREE_MB} MB\n"
    
    if [ $USED_MB -gt $SD_FREE_MB ]; then
        printf "${RED}ERROR: Not enough space on storage destination (need ~${EST_COMPRESSED_MB} MB)${NC}\n"
        return 1
    fi
    
    printf "${GREEN}✓ Sufficient space available${NC}\n"
    return 0
}

create_tarball() {
    timestamp=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_TAR="$SDCARD_PATH/termux-backup-${timestamp}.tar.gz"
    
    printf "\n${BLUE}=== Creating tar.gz archive ===${NC}\n"
    printf "Output: $OUTPUT_TAR\n"
    printf "Options: Preserve symlinks, permissions, ownership\n"
    printf "\nThis can take several minutes depending on your storage speed...\n\n"
    
    if [ -f "$OUTPUT_TAR" ]; then
        printf "Removing existing conflicting file...\n"
        rm -f "$OUTPUT_TAR"
    fi
    
    printf "Creating compressed archive...\n"
    
    # Targets home and usr directories explicitly inside the root file environment
    # Excludes the backup file itself if accidentally routed inside the target
    if tar -czpf "$OUTPUT_TAR" --exclude='home/storage' -C "$TERMUX_FILES" home usr 2>&1 | tail -20; then
        printf "\n${GREEN}✓ Archive created successfully${NC}\n"
    else
        printf "\n${RED}ERROR: Failed to create archive${NC}\n"
        return 1
    fi
    
    sync
    sleep 2
    
    return 0
}

verify_tarball() {
    printf "\n${BLUE}=== Verifying archive ===${NC}\n"
    
    if [ ! -f "$OUTPUT_TAR" ]; then
        printf "${RED}ERROR: Archive file not found!${NC}\n"
        return 1
    fi
    
    FINAL_SIZE=$(ls -lh "$OUTPUT_TAR" | awk '{print $5}')
    printf "Archive size: $FINAL_SIZE\n"
    
    # Test archive integrity
    printf "\nTesting archive integrity...\n"
    if tar -tzf "$OUTPUT_TAR" >/dev/null 2>&1; then
        printf "${GREEN}✓ Archive structure is valid${NC}\n"
    else
        printf "${RED}ERROR: Archive is corrupted or structurally broken${NC}\n"
        return 1
    fi
    
    # Count files in archive
    printf "\nCounting files in archive...\n"
    ARCHIVED_FILES=$(tar -tzf "$OUTPUT_TAR" 2>/dev/null | wc -l)
    printf "Items safely inside archive: $ARCHIVED_FILES\n"
    
    # Show sample contents
    printf "\nSample contents (first 20 items):\n"
    tar -tzf "$OUTPUT_TAR" 2>/dev/null | head -20
    
    printf "\n${GREEN}✓ Verification complete${NC}\n"
    
    return 0
}

main() {
    printf "${BLUE}╔════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║  Termux Filesystem → tar.gz Backup     ║${NC}\n"
    printf "${BLUE}║  Preserves: packages, profiles, config ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n"
    printf "\n"
    
    detect_sdcard_path || exit 1
    printf "\n"
    
    validate_termux_env || exit 1
    
    check_space || exit 1
    
    printf "\n${YELLOW}Ready to create system backup${NC}\n"
    printf "Source paths: $TERMUX_FILES/home and /usr\n"
    printf "Output: $SDCARD_PATH/termux-backup-TIMESTAMP.tar.gz\n"
    printf "Total estimated files: $TOTAL_FILES\n\n"
    
    printf "Proceed with core Termux backup? (y/n) "
    read -r reply
    case "$reply" in
        [Yy]*) ;;
        *) printf "${YELLOW}Cancelled${NC}\n"; exit 0 ;;
    esac
    
    create_tarball || exit 1
    verify_tarball || exit 1
    
    printf "\n========================================\n"
    printf "${GREEN}✓ SYSTEM BACKUP COMPLETED SUCCESSFULLY${NC}\n"
    printf "========================================\n"
    printf "\nBackup Summary:\n"
    printf "- Base System: $TERMUX_FILES\n"
    printf "- Backup File: $OUTPUT_TAR\n"
    printf "- Final Archive Size: $FINAL_SIZE\n"
    printf "- Indexed Items: $ARCHIVED_FILES\n"
    
    printf "\nTo completely restore your system later (on clean Termux install):\n"
    printf "  1. Ensure storage permission is enabled (termux-setup-storage)\n"
    printf "  2. Clear current broken setup: rm -rf /data/data/com.termux/files/usr /data/data/com.termux/files/home\n"
    printf "  3. Extract safely: tar -xzpf $OUTPUT_TAR -C /data/data/com.termux/files/\n"
    printf "  4. Close and completely restart the Termux App context.\n"
    printf "\n${GREEN}✓✓✓ DONE ✓✓✓${NC}\n"
}

main "$@"