#!/data/data/com.termux/files/usr/bin/bash

# Backup Termux Ubuntu folder to tar.gz
# Preserves symlinks, permissions, and all file attributes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
TERMUX_HOME="/data/data/com.termux/files/home"
UBUNTU_FOLDER="${TERMUX_HOME}/ubuntu"

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

validate_ubuntu_folder() {
    printf "${BLUE}=== Validating Ubuntu folder ===${NC}\n"
    
    if [ ! -d "$UBUNTU_FOLDER" ]; then
        printf "${RED}ERROR: Ubuntu folder not found at $UBUNTU_FOLDER${NC}\n"
        printf "${YELLOW}Checking alternates...${NC}\n"
        
        for alt in "$TERMUX_HOME/ubuntu-fs" "$TERMUX_HOME/ubuntu-rootfs" "$(pwd)/ubuntu"; do
            if [ -d "$alt" ]; then
                UBUNTU_FOLDER="$alt"
                printf "${GREEN}✓ Found at $UBUNTU_FOLDER${NC}\n"
                return 0
            fi
        done
        
        return 1
    fi
    
    printf "${GREEN}✓ Ubuntu folder: $UBUNTU_FOLDER${NC}\n"
    
    # Show what will be archived
    printf "\nTop-level contents:\n"
    ls -1 "$UBUNTU_FOLDER" | head -15
    
    # Count items
    printf "\nCounting files and directories...\n"
    TOTAL_FILES=$(find "$UBUNTU_FOLDER" -type f 2>/dev/null | wc -l)
    TOTAL_DIRS=$(find "$UBUNTU_FOLDER" -type d 2>/dev/null | wc -l)
    TOTAL_LINKS=$(find "$UBUNTU_FOLDER" -type l 2>/dev/null | wc -l)
    
    printf "Files: $TOTAL_FILES\n"
    printf "Directories: $TOTAL_DIRS\n"
    printf "Symlinks: $TOTAL_LINKS\n"
    
    return 0
}

check_space() {
    printf "\n${BLUE}=== Space Check ===${NC}\n"
    
    printf "Calculating folder size...\n"
    USED_SPACE=$(du -sh "$UBUNTU_FOLDER" 2>/dev/null | cut -f1)
    USED_KB=$(du -sk "$UBUNTU_FOLDER" 2>/dev/null | awk '{print $1}')
    USED_MB=$((USED_KB / 1024))
    
    printf "Ubuntu folder size: $USED_SPACE\n"
    
    # Estimate compressed size (usually 30-50% of original)
    EST_COMPRESSED_MB=$((USED_MB / 2))
    printf "Estimated tar.gz size: ~${EST_COMPRESSED_MB} MB\n"
    
    SD_FREE=$(df -k "$SDCARD_PATH" | tail -1 | awk '{print $4}')
    SD_FREE_MB=$((SD_FREE / 1024))
    printf "SD card available: ${SD_FREE_MB} MB\n"
    
    if [ $USED_MB -gt $SD_FREE_MB ]; then
        printf "${RED}ERROR: Not enough space (need ~${EST_COMPRESSED_MB} MB)${NC}\n"
        return 1
    fi
    
    printf "${GREEN}✓ Sufficient space${NC}\n"
    return 0
}

create_tarball() {
    timestamp=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_TAR="$SDCARD_PATH/ubuntu-backup-${timestamp}.tar.gz"
    
    printf "\n${BLUE}=== Creating tar.gz archive ===${NC}\n"
    printf "Output: $OUTPUT_TAR\n"
    printf "Options: Preserve symlinks, permissions, ownership\n"
    printf "\nThis will take 10-30 minutes...\n\n"
    
    # Remove old file if exists
    if [ -f "$OUTPUT_TAR" ]; then
        printf "Removing existing file...\n"
        rm -f "$OUTPUT_TAR"
    fi
    
    printf "Creating compressed archive...\n"
    printf "Progress will be shown below:\n\n"
    
    # Create tar with:
    # -c = create archive
    # -z = compress with gzip
    # -f = output file
    # -p = preserve permissions
    # -h = follow symlinks (use -h) OR keep symlinks as-is (don't use -h)
    # -v = verbose (show progress)
    # -C = change to directory first
    
    # Create archive preserving symlinks
    if tar -czpf "$OUTPUT_TAR" -C "$UBUNTU_FOLDER" . 2>&1 | tail -20; then
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
        printf "${GREEN}✓ Archive is valid${NC}\n"
    else
        printf "${RED}ERROR: Archive is corrupted${NC}\n"
        return 1
    fi
    
    # Count files in archive
    printf "\nCounting files in archive...\n"
    ARCHIVED_FILES=$(tar -tzf "$OUTPUT_TAR" 2>/dev/null | wc -l)
    printf "Items in archive: $ARCHIVED_FILES\n"
    
    # Show sample contents
    printf "\nSample contents (first 20 items):\n"
    tar -tzf "$OUTPUT_TAR" 2>/dev/null | head -20
    
    printf "\n${GREEN}✓ Verification complete${NC}\n"
    
    return 0
}

main() {
    printf "${BLUE}╔════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║  Ubuntu Folder → tar.gz Backup         ║${NC}\n"
    printf "${BLUE}║  Preserves: symlinks, perms, owner     ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n"
    printf "\n"
    
    detect_sdcard_path || exit 1
    printf "\n"
    
    validate_ubuntu_folder || exit 1
    
    check_space || exit 1
    
    printf "\n${YELLOW}Ready to create tar.gz backup${NC}\n"
    printf "Source: $UBUNTU_FOLDER\n"
    printf "Output: $SDCARD_PATH/ubuntu-backup-TIMESTAMP.tar.gz\n"
    printf "Files: $TOTAL_FILES\n"
    printf "Symlinks: $TOTAL_LINKS (will be preserved)\n\n"
    
    printf "Proceed? (y/n) "
    read -r reply
    case "$reply" in
        [Yy]*) ;;
        *) printf "${YELLOW}Cancelled${NC}\n"; exit 0 ;;
    esac
    
    create_tarball || exit 1
    verify_tarball || exit 1
    
    printf "\n========================================\n"
    printf "${GREEN}✓ BACKUP COMPLETED SUCCESSFULLY${NC}\n"
    printf "========================================\n"
    printf "\nBackup Summary:\n"
    printf "- Source: $UBUNTU_FOLDER\n"
    printf "- Output: $OUTPUT_TAR\n"
    printf "- Size: $FINAL_SIZE\n"
    printf "- Items: $ARCHIVED_FILES\n"
    printf "\nTo extract later:\n"
    printf "  mkdir ubuntu-restored\n"
    printf "  tar -xzpf $OUTPUT_TAR -C ubuntu-restored/\n"
    printf "\nOr to extract with root (preserves ownership):\n"
    printf "  su\n"
    printf "  tar -xzpf $OUTPUT_TAR -C /path/to/destination/\n"
    printf "\n${GREEN}✓✓✓ DONE ✓✓✓${NC}\n"
}

main "$@"
