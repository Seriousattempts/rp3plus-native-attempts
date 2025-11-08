#!/bin/bash

# Debian Device Permission Setup Script
# Configures permissions and group assignments for all devices in chroot environment

# Environment validation
if [ -z "$SD_MOUNT" ]; then
    echo "Error: SD_MOUNT environment variable not set"
    exit 1
fi

# Set up logging
LOG_FILE="/data/dev-nodes-logs.log"

# Initialize log file
{
    echo "========================================="
    echo "Device Permission Setup Script (Debian)"
    echo "Started: $(date)"
    echo "Log file: $LOG_FILE"
    echo "Environment: $(uname -a)"
    echo "========================================="
} | tee -a "$LOG_FILE"

# Enhanced user detection for chroot compatibility
get_current_user() {
    local user=""

    if [ -n "$USER" ]; then
        user="$USER"
    elif [ -n "$LOGNAME" ]; then
        user="$LOGNAME"
    elif user=$(whoami 2>/dev/null); then
        :
    elif user=$(id -un 2>/dev/null); then
        :
    fi

    # Default fallback
    if [ -z "$user" ] || [ "$user" = "root" ]; then
        user="p3plus"
        echo "Warning: Could not determine user, defaulting to 'p3plus'" | tee -a "$LOG_FILE"
    fi

    echo "$user"
}

CURRENT_USER=$(get_current_user)
echo "Current user: $CURRENT_USER" | tee -a "$LOG_FILE"

# Function to check if group exists
group_exists() {
    local group_name="$1"
    getent group "$group_name" >/dev/null 2>&1
    return $?
}

# Function to check if user is in group
user_in_group() {
    local username="$1"
    local groupname="$2"
    
    id -nG "$username" 2>/dev/null | grep -qw "$groupname"
    return $?
}

# Function to create group safely (DEBIAN SYNTAX)
create_group_safe() {
    local group_name="$1"
    local gid="$2"

    if ! group_exists "$group_name"; then
        echo "Creating group: $group_name (GID: $gid)" | tee -a "$LOG_FILE"
        # Debian syntax: groupadd -g GID groupname
        if groupadd -g "$gid" "$group_name" 2>&1 | tee -a "$LOG_FILE"; then
            echo "✓ Group $group_name created successfully" | tee -a "$LOG_FILE"
        else
            echo "✗ Failed to create group $group_name" | tee -a "$LOG_FILE"
            return 1
        fi
    else
        echo "Group $group_name already exists" | tee -a "$LOG_FILE"
    fi
    return 0
}

# Function to add user to group safely (DEBIAN SYNTAX)
add_user_to_group_safe() {
    local username="$1"
    local groupname="$2"

    # Check if group exists first
    if ! group_exists "$groupname"; then
        echo "Warning: Group $groupname does not exist, skipping user assignment" | tee -a "$LOG_FILE"
        return 1
    fi

    # Check if user is already in group
    if user_in_group "$username" "$groupname"; then
        echo "User $username already in group $groupname" | tee -a "$LOG_FILE"
        return 0
    fi

    # Add user to group - Debian syntax: usermod -aG groupname username
    echo "Adding $username to group: $groupname" | tee -a "$LOG_FILE"
    if usermod -aG "$groupname" "$username" 2>&1 | tee -a "$LOG_FILE"; then
        echo "✓ User $username added to group $groupname" | tee -a "$LOG_FILE"
        return 0
    else
        echo "✗ Failed to add user $username to group $groupname" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Enhanced function to set device permissions with wildcard pattern matching
setup_device_safe() {
    local device="$1"
    local group_name="$2"
    local perms="$3"

    # Handle wildcard pattern matching for dynamic devices
    if echo "$device" | grep -q '\*'; then
        echo "Setting up devices matching pattern: $device" | tee -a "$LOG_FILE"
        # Find all matching devices
        for matched_dev in $device; do
            if [ -e "$matched_dev" ] || [ -L "$matched_dev" ]; then
                # Recursive call without wildcard
                setup_device_safe "$matched_dev" "$group_name" "$perms"
            fi
        done
        return 0
    fi

    if [ -e "$device" ] || [ -L "$device" ]; then
        echo "Setting up: $device -> $group_name:$perms" | tee -a "$LOG_FILE"

        # Set permissions
        if chmod "$perms" "$device" 2>&1 | tee -a "$LOG_FILE"; then
            echo "  ✓ Permissions set to $perms" | tee -a "$LOG_FILE"
        else
            echo "  ✗ Failed to set permissions" | tee -a "$LOG_FILE"
        fi

        # Set group ownership if group exists
        if group_exists "$group_name"; then
            if chgrp "$group_name" "$device" 2>&1 | tee -a "$LOG_FILE"; then
                echo "  ✓ Group ownership set to $group_name" | tee -a "$LOG_FILE"
            else
                echo "  ✗ Failed to set group ownership" | tee -a "$LOG_FILE"
            fi
        else
            echo "  ! Group $group_name does not exist, skipping ownership change" | tee -a "$LOG_FILE"
        fi
    else
        echo "Device not found: $device" | tee -a "$LOG_FILE"
    fi
}

# Create all necessary Debian groups
echo "Setting up Debian groups..." | tee -a "$LOG_FILE"

# Core system groups with proper GIDs (Debian standard)
create_group_safe "root" 0
create_group_safe "daemon" 1
create_group_safe "bin" 2
create_group_safe "sys" 3
create_group_safe "adm" 4
create_group_safe "tty" 5
create_group_safe "disk" 6
create_group_safe "lp" 7
create_group_safe "mail" 8
create_group_safe "news" 9
create_group_safe "uucp" 10
create_group_safe "man" 12
create_group_safe "proxy" 13
create_group_safe "kmem" 15
create_group_safe "dialout" 20
create_group_safe "fax" 21
create_group_safe "voice" 22
create_group_safe "cdrom" 24
create_group_safe "floppy" 25
create_group_safe "tape" 26
create_group_safe "sudo" 27
create_group_safe "audio" 29
create_group_safe "dip" 30
create_group_safe "www-data" 33
create_group_safe "backup" 34
create_group_safe "operator" 37
create_group_safe "list" 38
create_group_safe "irc" 39
create_group_safe "src" 40
create_group_safe "gnats" 41
create_group_safe "shadow" 42
create_group_safe "utmp" 43
create_group_safe "video" 44
create_group_safe "sasl" 45
create_group_safe "plugdev" 46
create_group_safe "staff" 50
create_group_safe "games" 60
create_group_safe "users" 100
create_group_safe "nogroup" 65534

# Additional groups for hardware access
create_group_safe "input" 104
create_group_safe "kvm" 108
create_group_safe "render" 109
create_group_safe "netdev" 110
create_group_safe "bluetooth" 111
create_group_safe "lpadmin" 112
create_group_safe "pulse" 113
create_group_safe "pulse-access" 114
create_group_safe "scanner" 115
create_group_safe "saned" 116
create_group_safe "colord" 117
create_group_safe "ssl-cert" 118

# Android-specific groups
create_group_safe "graphics" 1003
create_group_safe "log" 1007
create_group_safe "mount" 1009
create_group_safe "wifi" 1010
create_group_safe "install" 1012
create_group_safe "dhcp" 1014
create_group_safe "media_rw" 1023
create_group_safe "mtp" 1024
create_group_safe "drmrpc" 1026
create_group_safe "shell" 2000
create_group_safe "cache" 2001
create_group_safe "diag" 2002

# Legacy Unix groups (for compatibility)
create_group_safe "wheel" 11
create_group_safe "mem" 8
create_group_safe "ftp" 21
create_group_safe "sshd" 22
create_group_safe "at" 25
create_group_safe "readproc" 30
create_group_safe "squid" 31
create_group_safe "gdm" 32
create_group_safe "xfs" 33
create_group_safe "named" 40
create_group_safe "mysql" 60
create_group_safe "postgres" 70
create_group_safe "cdrw" 80
create_group_safe "apache" 81
create_group_safe "nut" 84
create_group_safe "usb" 85
create_group_safe "avahi" 86
create_group_safe "vpopmail" 89
create_group_safe "ntp" 123
create_group_safe "nofiles" 200
create_group_safe "qmail" 201
create_group_safe "postfix" 207
create_group_safe "postdrop" 208
create_group_safe "smmsp" 209
create_group_safe "slocate" 245
create_group_safe "abuild" 300
create_group_safe "nobody" 65534

echo "Setting up device permissions..." | tee -a "$LOG_FILE"

# Storage devices (disk group)
setup_device_safe "/dev/loop0" "disk" "666"
setup_device_safe "/dev/loop1" "disk" "666"
setup_device_safe "/dev/loop2" "disk" "666"
setup_device_safe "/dev/loop3" "disk" "666"
setup_device_safe "/dev/loop4" "disk" "666"
setup_device_safe "/dev/loop5" "disk" "666"
setup_device_safe "/dev/loop6" "disk" "666"
setup_device_safe "/dev/loop-control" "disk" "666"

# Serial/TTY devices (dialout group)
setup_device_safe "/dev/ttyGS0" "dialout" "666"
setup_device_safe "/dev/ttyGS1" "dialout" "666"
setup_device_safe "/dev/ttyGS2" "dialout" "666"
setup_device_safe "/dev/ttyGS3" "dialout" "666"
setup_device_safe "/dev/ttyGS4" "dialout" "666"
setup_device_safe "/dev/ttyGS5" "dialout" "666"
setup_device_safe "/dev/ttyGS6" "dialout" "666"
setup_device_safe "/dev/ttyGS7" "dialout" "666"
setup_device_safe "/dev/ttyS0" "dialout" "666"
setup_device_safe "/dev/ttyS1" "dialout" "666"
setup_device_safe "/dev/ttyBT0" "dialout" "666"
setup_device_safe "/dev/ttyBT1" "dialout" "666"
setup_device_safe "/dev/tty" "tty" "666"
setup_device_safe "/dev/console" "tty" "620"

# LTE communication devices (dialout group)
for i in $(seq 0 14); do
    setup_device_safe "/dev/spipe_lte$i" "dialout" "666"
done

for i in $(seq 0 31); do
    setup_device_safe "/dev/stty_lte$i" "dialout" "666"
done

setup_device_safe "/dev/sdiag_lte" "dialout" "666"

# USB devices (usb/plugdev group)
setup_device_safe "/dev/usb_accessory" "plugdev" "666"
setup_device_safe "/dev/mtp_usb" "plugdev" "666"
setup_device_safe "/dev/vser" "dialout" "666"
setup_device_safe "/dev/bus/usb/001/001" "plugdev" "666"

# Standard I/O (root group, readable/writable)
setup_device_safe "/dev/stdin" "root" "666"
setup_device_safe "/dev/stdout" "root" "666"
setup_device_safe "/dev/stderr" "root" "666"
setup_device_safe "/dev/null" "root" "666"
setup_device_safe "/dev/zero" "root" "666"
setup_device_safe "/dev/full" "root" "666"
setup_device_safe "/dev/random" "root" "666"
setup_device_safe "/dev/urandom" "root" "666"

# Network devices (netdev group)
setup_device_safe "/dev/ppp" "netdev" "666"
setup_device_safe "/dev/tun" "netdev" "666"
setup_device_safe "/dev/rfkill" "netdev" "666"

# Audio devices (audio group)
setup_device_safe "/dev/apipe-cmd-in" "audio" "666"
setup_device_safe "/dev/apipe-cmd-out" "audio" "666"
setup_device_safe "/dev/apipe-pcm" "audio" "666"
setup_device_safe "/dev/audio_pipe_effect" "audio" "666"
setup_device_safe "/dev/audio_pipe_bthal" "audio" "666"
setup_device_safe "/dev/audio_pipe_voice" "audio" "666"
setup_device_safe "/dev/audio_pipe_recordproc" "audio" "666"

# Sound devices (audio group) - All ALSA devices
for device in /dev/snd/*; do
    [ -e "$device" ] && setup_device_safe "$device" "audio" "666"
done

# Video/Graphics devices (video group)
setup_device_safe "/dev/dri/card0" "video" "666"
setup_device_safe "/dev/dri/renderD128" "render" "666"
setup_device_safe "/dev/mali0" "video" "666"
setup_device_safe "/dev/gsp" "video" "666"
setup_device_safe "/dev/retrostation_hdmi" "video" "666"
setup_device_safe "/dev/sprd_vsp" "video" "666"
setup_device_safe "/dev/sprd_jpg" "video" "666"
setup_device_safe "/dev/sprd_cpp" "video" "666"
setup_device_safe "/dev/vdsp0" "video" "666"

# Video capture devices (video0-15)
for i in $(seq 0 15); do
    setup_device_safe "/dev/video$i" "video" "666"
done

# Media controller devices (media0-3)
for i in $(seq 0 3); do
    setup_device_safe "/dev/media$i" "video" "666"
done

# V4L2 subdev devices (v4l-subdev0-7)
for i in $(seq 0 7); do
    setup_device_safe "/dev/v4l-subdev$i" "video" "666"
done

# Input devices (input group)
for device in /dev/input/*; do
    [ -e "$device" ] && setup_device_safe "$device" "input" "666"
done

setup_device_safe "/dev/uinput" "input" "666"
setup_device_safe "/dev/uhid" "input" "666"

# GPIO devices (sys group - system hardware)
for i in $(seq 0 5); do
    setup_device_safe "/dev/gpiochip$i" "sys" "666"
done

# I2C devices (sys group)
for i in $(seq 0 5); do
    setup_device_safe "/dev/i2c-$i" "sys" "666"
done

# Sensor devices (sys group)
setup_device_safe "/dev/iio:device0" "sys" "666"
setup_device_safe "/dev/iio:device1" "sys" "666"
setup_device_safe "/dev/sprd_sensor" "sys" "666"
setup_device_safe "/dev/sprd_flash" "video" "666"

# RTC device (sys group)
setup_device_safe "/dev/rtc0" "sys" "666"

# Memory devices
setup_device_safe "/dev/ashmem" "mem" "666"
for device in /dev/ashmem*; do
    [ -e "$device" ] && setup_device_safe "$device" "mem" "666"
done
setup_device_safe "/dev/ion" "mem" "666"

# Wireless/Communication devices (netdev group)
setup_device_safe "/dev/wcn" "netdev" "666"
setup_device_safe "/dev/wcn_op" "netdev" "666"
setup_device_safe "/dev/fm" "netdev" "666"

# GNSS/GPS devices (sys group)
setup_device_safe "/dev/gnss_dbg" "sys" "666"
setup_device_safe "/dev/gnss_common_ctl" "sys" "666"
setup_device_safe "/dev/gnss_pmnotify_ctl" "sys" "666"
setup_device_safe "/dev/data0_gnss" "sys" "666"

# System log devices (adm group)
setup_device_safe "/dev/slog_gnss" "adm" "664"
setup_device_safe "/dev/slog_pm" "adm" "664"
setup_device_safe "/dev/slog_lte" "adm" "664"
setup_device_safe "/dev/slog_wcn0" "adm" "664"
setup_device_safe "/dev/slog_wcn1" "adm" "664"

# Power management devices (sys group)
setup_device_safe "/dev/spipe_pm0" "sys" "666"
setup_device_safe "/dev/spipe_pm1" "sys" "666"
setup_device_safe "/dev/sctl_pm" "sys" "666"

# Hardware control devices (sys group)
setup_device_safe "/dev/cptl" "sys" "666"
setup_device_safe "/dev/sprd_uid" "sys" "666"
setup_device_safe "/dev/autotest0" "sys" "666"
setup_device_safe "/dev/map_user" "sys" "666"

# Filesystem in userspace
setup_device_safe "/dev/fuse" "users" "666"

# TTY and system devices
setup_device_safe "/dev/ptmx" "tty" "666"
setup_device_safe "/dev/kmsg" "adm" "644"

# Block devices (disk group)
echo "Setting up block devices..." | tee -a "$LOG_FILE"

# MMC devices
setup_device_safe "/dev/block/mmcblk0" "disk" "640"
setup_device_safe "/dev/block/mmcblk1" "disk" "666"

# MMC partitions
for i in $(seq 1 77); do
    [ -e "/dev/block/mmcblk0p$i" ] && setup_device_safe "/dev/block/mmcblk0p$i" "disk" "666"
done

# Binder IPC devices
setup_device_safe "/dev/binder" "root" "666"
setup_device_safe "/dev/hwbinder" "root" "666"
setup_device_safe "/dev/vndbinder" "root" "666"

# Add current user to essential device access groups
echo "Adding $CURRENT_USER to essential device access groups..." | tee -a "$LOG_FILE"

essential_groups="root audio video input dialout plugdev netdev bluetooth disk tty adm sudo users render kvm render"
for group in $essential_groups; do
    add_user_to_group_safe "$CURRENT_USER" "$group"
done

# Final status report
device_count=$(grep -c "Setting up:" "$LOG_FILE" 2>/dev/null || echo "0")
error_count=$(grep -c "✗" "$LOG_FILE" 2>/dev/null || echo "0")
success_count=$(grep -c "✓" "$LOG_FILE" 2>/dev/null || echo "0")

{
    echo "========================================="
    echo "Device setup completed: $(date)"
    echo "Devices processed: $device_count"
    echo "Successful operations: $success_count"
    echo "Failed operations: $error_count"
    echo "Log saved to: $LOG_FILE"
    echo "========================================="
} | tee -a "$LOG_FILE"

# Display user groups
echo "Current groups for user $CURRENT_USER:" | tee -a "$LOG_FILE"
groups "$CURRENT_USER" 2>/dev/null | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Setup complete. Please log out and log back in for group changes to take effect." | tee -a "$LOG_FILE"
echo "Run 'cat $LOG_FILE' to review the complete setup log." | tee -a "$LOG_FILE"
