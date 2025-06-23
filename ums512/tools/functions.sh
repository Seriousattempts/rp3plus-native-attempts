#!/sbin/sh

# UMS512 Dual Boot Functions - Native Interface Version
# Uses /proc, /sys, /dev for all operations

# Volume key detection for UMS512
chooseport() {
    local events_file=/tmp/events
    local count=0
    
    while true; do
        rm -f $events_file
        timeout 0.5 getevent -lqc 1 > $events_file 2>&1 &
        sleep 0.1
        count=$((count + 1))
        
        if grep -q 'KEY_VOLUMEUP *DOWN' $events_file; then
            rm -f $events_file
            return 0
        elif grep -q 'KEY_VOLUMEDOWN *DOWN' $events_file; then
            rm -f $events_file
            return 1
        fi
        
        if [ $count -ge 30 ]; then
            return 1  # Default to "No"
        fi
    done
}

# Unmount and refresh partitions
unmountAllAndRefreshPartitions() {
    ui_print "  → Unmounting all partitions..."
    mount | grep /dev/block/mmcblk0 | while read -r line; do
        thispart=$(echo "$line" | awk '{print $3}')
        umount -lf "$thispart" 2>/dev/null
    done
    
    ui_print "  → Refreshing partition table..."
    blockdev --rereadpt /dev/block/mmcblk0
    sleep 1
}

# Enhanced partition operations with detailed logging
change_part() {
    local action=$1
    local partnum=$2
    local parttype=$3
    
    ui_print "    → $action partition $partnum"
    
    case $action in
        "delete")
            sgdisk /dev/block/mmcblk0 --delete $partnum || abort "Failed to delete partition $partnum"
            ;;
        "new")
            sgdisk /dev/block/mmcblk0 --new=$partnum || abort "Failed to create partition $partnum"
            ;;
        "change-name")
            sgdisk /dev/block/mmcblk0 --change-name=$partnum || abort "Failed to rename partition $partnum"
            ;;
        "format")
            if [ "$parttype" = "f2fs" ]; then
                ui_print "      → Formatting as F2FS..."
                mkfs.f2fs -f -w 4096 /dev/block/mmcblk0p$partnum || abort "F2FS format failed"
                sload.f2fs -t /data /dev/block/mmcblk0p$partnum
            else
                ui_print "      → Formatting as EXT4..."
                mke2fs -F -t ext4 -b 4096 /dev/block/mmcblk0p$partnum || abort "EXT4 format failed"
                e2fsdroid -e -a /data /dev/block/mmcblk0p$partnum
            fi
            ;;
        *) abort "Unknown partition action: $action" ;;
    esac
}

# UMS512 A/B repartitioning using /sys/block data
repartition_userdata() {
    ui_print "  → Analyzing current partition layout via /sys/block..."
    
    # Get userdata partition info from /sys/block
    if [ -f "/sys/block/mmcblk0/mmcblk0p76/start" ]; then
        userdata_start=$(cat /sys/block/mmcblk0/mmcblk0p76/start)
        userdata_size=$(cat /sys/block/mmcblk0/mmcblk0p76/size)
        userdata_end=$((userdata_start + userdata_size - 1))
        
        ui_print "    ✓ Userdata start: $userdata_start"
        ui_print "    ✓ Userdata size: $userdata_size sectors"
        ui_print "    ✓ Userdata end: $userdata_end"
    else
        abort "Cannot read userdata partition info from /sys/block"
    fi
    
    # Calculate A/B partition layout
    metadata_size=32768  # 16MB in 512-byte sectors
    available_size=$((userdata_size - metadata_size))
    slot_size=$((available_size / 2))
    
    # Partition boundaries
    userdata_a_start=$userdata_start
    userdata_a_end=$((userdata_a_start + slot_size - 1))
    
    metadata_b_start=$((userdata_a_end + 1))
    metadata_b_end=$((metadata_b_start + metadata_size - 1))
    
    userdata_b_start=$((metadata_b_end + 1))
    userdata_b_end=$userdata_end
    
    ui_print "  → Calculated A/B layout:"
    ui_print "    • userdata_a (76): $userdata_a_start to $userdata_a_end"
    ui_print "    • metadata_b (77): $metadata_b_start to $metadata_b_end"
    ui_print "    • userdata_b (78): $userdata_b_start to $userdata_b_end"
    
    # Execute repartitioning
    ui_print "  → Executing partition changes..."
    
    # Rename metadata to metadata_a
    change_part change-name "58:metadata_a"
    
    # Delete original userdata
    change_part delete 76
    
    # Create userdata_a
    change_part new "76:$userdata_a_start:$userdata_a_end"
    change_part change-name "76:userdata_a"
    
    # Create metadata_b
    change_part new "77:$metadata_b_start:$metadata_b_end"
    change_part change-name "77:metadata_b"
    
    # Create userdata_b
    change_part new "78:$userdata_b_start:$userdata_b_end"
    change_part change-name "78:userdata_b"
    
    # Refresh partition table
    blockdev --rereadpt /dev/block/mmcblk0
    sync
    sleep 1
    
    ui_print "  → Formatting new partitions..."
    
    # Format partitions
    change_part format 76 "$typea"      # userdata_a
    change_part format 58 "ext4"        # metadata_a
    change_part format 78 "$typeb"      # userdata_b  
    change_part format 77 "ext4"        # metadata_b
    
    ui_print "  ✓ A/B repartitioning completed"
    
    # Verify using /proc/partitions
    ui_print "  → Verification via /proc/partitions:"
    grep -E "mmcblk0p(58|76|77|78)" /proc/partitions | while read line; do
        ui_print "    $line"
    done
}

# Simplified partition table patching for A/B
patch_fstabs() {
    ui_print "  → Patching fstab files for A/B support..."
    
    # Find UMS512 fstab files
    FSTABS=$(find /vendor/etc /odm/etc -name 'fstab.ums512*' 2>/dev/null)
    [ -z "$FSTABS" ] && FSTABS=$(find /system/etc -name 'fstab.*' 2>/dev/null | head -3)
    
    for fstab in $FSTABS; do
        [ -f "$fstab" ] || continue
        ui_print "    → Processing: $(basename $fstab)"
        
        # Backup
        cp "$fstab" "${fstab}.bak" 2>/dev/null
        
        # Add slotselect to userdata and metadata
        sed -ri '/by-name\/(userdata|metadata)/s/wait,/wait,slotselect,/g' "$fstab"
        
        # Remove encryption flags (commented out to prevent bootloop)
        # sed -i 's/fileencryption=[^,]*,*//g' "$fstab"
        # sed -i 's/encryptable=[^,]*,*//g' "$fstab"
        
        # Clean up
        sed -i -r 's/,,+/,/g; s/[[:space:]]+,/,/g; s/,[[:space:]]*$//g' "$fstab"
        
        ui_print "      ✓ Patched $(basename $fstab)"
    done
}

# Binary patches for boot image
binary_patches() {
    for dt in dtb kernel_dtb extra recovery_dtbo; do
        [ -f $dt ] && magiskboot dtb $dt patch && ui_print "    ✓ Patched fstab in $dt"
    done
    
    if [ -f kernel ]; then
        # Force kernel to load rootfs for dual boot
        magiskboot hexpatch kernel \
            736B69705F696E697472616D667300 \
            77616E745F696E697472616D667300
        ui_print "    ✓ Kernel patched for dual boot"
    fi
}

# Set permissions with error handling
set_perm() {
    local path="$1"
    local owner="$2"
    local group="$3"
    local perms="$4"
    local context="$5"
    
    if [ -e "$path" ]; then
        chown "$owner:$group" "$path" 2>/dev/null
        chmod "$perms" "$path" 2>/dev/null
        [ -n "$context" ] && chcon "$context" "$path" 2>/dev/null
        ui_print "    ✓ Permissions set: $path"
    fi
}
