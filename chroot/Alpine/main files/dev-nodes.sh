#!/bin/sh

# Alpine Linux Device Permission Setup Script
# Configures permissions and group assignments for all devices in chroot environment

# Environment validation
if [ -z "$SD_MOUNT" ]; then
    echo "Error: SD_MOUNT environment variable not set"
    exit 1
fi

# Set up logging (simplified approach for chroot compatibility)
LOG_FILE="/data/dev-nodes-logs.log"

# Busybox detection and compatibility
BUSYBOX_BIN=""
if [ -x "/bin/busybox" ]; then
    BUSYBOX_BIN="/bin/busybox"
    echo "Using busybox from /bin/busybox" | tee -a "$LOG_FILE"
elif [ -x "/system/bin/busybox" ]; then
    BUSYBOX_BIN="/system/bin/busybox"
    echo "Using busybox from /system/bin/busybox" | tee -a "$LOG_FILE"
else
    echo "Warning: busybox not found, using system commands" | tee -a "$LOG_FILE"
fi

# Function to run commands with POSIX-compatible grep
run_cmd() {
    local cmd="$1"
    shift
    local args="$@"

    # Use system command directly - more reliable than busybox in chroot
    if command -v "$cmd" >/dev/null 2>&1; then
        "$cmd" $args 2>/dev/null
        return $?
    fi
    return 1
}

# Initialize log file
{
    echo "========================================="
    echo "Device Permission Setup Script"
    echo "Started: $(date)"
    echo "Log file: $LOG_FILE"
    echo "Environment: $(uname -a)"
    echo "Busybox: ${BUSYBOX_BIN:-'system commands'}"
    echo "========================================="
} | tee -a "$LOG_FILE"

# Enhanced user detection for chroot compatibility
get_current_user() {
    local user=""

    # Try multiple methods for user detection
    if [ -n "$USER" ]; then
        user="$USER"
    elif [ -n "$LOGNAME" ]; then
        user="$LOGNAME"
    elif user=$(whoami 2>/dev/null); then
        # whoami worked
        :
    elif user=$(id -un 2>/dev/null); then
        # id worked
        :
    elif [ -r "/proc/self/loginuid" ] && [ "$(cat /proc/self/loginuid 2>/dev/null)" != "4294967295" ]; then
        # Try to get user from loginuid if available
        local uid=$(cat /proc/self/loginuid 2>/dev/null)
        if [ -n "$uid" ] && [ "$uid" != "4294967295" ]; then
            user=$(getent passwd "$uid" 2>/dev/null | cut -d: -f1)
        fi
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

# Function to check if group exists using POSIX-compatible grep
group_exists() {
    local group_name="$1"
    if [ -f "/etc/group" ]; then
        # POSIX-compatible: use grep with simple pattern
        grep "^${group_name}:" /etc/group >/dev/null 2>&1
        return $?
    else
        echo "Warning: /etc/group not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to check if user is in group using POSIX-compatible grep
user_in_group() {
    local username="$1"
    local groupname="$2"

    if [ -f "/etc/group" ]; then
        # POSIX-compatible: check for user in group line
        # Pattern matches: :username at end, :username, in middle, or ,username anywhere
        local group_line=$(grep "^${groupname}:" /etc/group 2>/dev/null)
        if [ -n "$group_line" ]; then
            # Check if username appears in the members list
            # Match: :username$ or :username, or ,username, or ,username$
            echo "$group_line" | grep ":${username}$" >/dev/null 2>&1 && return 0
            echo "$group_line" | grep ":${username}," >/dev/null 2>&1 && return 0
            echo "$group_line" | grep ",${username}," >/dev/null 2>&1 && return 0
            echo "$group_line" | grep ",${username}$" >/dev/null 2>&1 && return 0
        fi
    fi
    return 1
}

# Function to create group safely (Alpine Linux syntax)
create_group_safe() {
    local group_name="$1"
    local gid="$2"

    if ! group_exists "$group_name"; then
        echo "Creating group: $group_name (GID: $gid)" | tee -a "$LOG_FILE"
        if addgroup -g "$gid" -S "$group_name" 2>&1 | tee -a "$LOG_FILE"; then
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

# Function to add user to group safely
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

    # Add user to group
    echo "Adding $username to group: $groupname" | tee -a "$LOG_FILE"
    if addgroup "$username" "$groupname" 2>&1 | tee -a "$LOG_FILE"; then
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
    if echo "$device" | grep '\*' >/dev/null 2>&1; then
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

# Create all necessary Alpine Linux groups
echo "Setting up Alpine Linux groups..." | tee -a "$LOG_FILE"

# Core system groups with proper GIDs
create_group_safe "root" 0
create_group_safe "bin" 1
create_group_safe "daemon" 2
create_group_safe "sys" 3
create_group_safe "adm" 4
create_group_safe "tty" 5
create_group_safe "disk" 6
create_group_safe "lp" 7
create_group_safe "mem" 8
create_group_safe "kmem" 9
create_group_safe "wheel" 10
create_group_safe "floppy" 11
create_group_safe "mail" 12
create_group_safe "news" 13
create_group_safe "uucp" 14
create_group_safe "man" 15
create_group_safe "cron" 16
create_group_safe "console" 17
create_group_safe "audio" 18
create_group_safe "cdrom" 19
create_group_safe "dialout" 20
create_group_safe "ftp" 21
create_group_safe "sshd" 22
create_group_safe "at" 25
create_group_safe "tape" 26
create_group_safe "video" 27
create_group_safe "netdev" 28
create_group_safe "readproc" 30
create_group_safe "squid" 31
create_group_safe "gdm" 32
create_group_safe "xfs" 33
create_group_safe "kvm" 34
create_group_safe "games" 35
create_group_safe "named" 40
create_group_safe "mysql" 60
create_group_safe "postgres" 70
create_group_safe "cdrw" 80
create_group_safe "apache" 81
create_group_safe "nut" 84
create_group_safe "usb" 85
create_group_safe "avahi" 86
create_group_safe "vpopmail" 89
create_group_safe "users" 100
create_group_safe "ntp" 123
create_group_safe "nofiles" 200
create_group_safe "qmail" 201
create_group_safe "postfix" 207
create_group_safe "postdrop" 208
create_group_safe "smmsp" 209
create_group_safe "slocate" 245
create_group_safe "abuild" 300
create_group_safe "utmp" 406
create_group_safe "nogroup" 65533
create_group_safe "nobody" 65534
create_group_safe "input" 97
create_group_safe "bluetooth" 3003
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

# USB devices (usb group)
setup_device_safe "/dev/usb_accessory" "usb" "666"
setup_device_safe "/dev/mtp_usb" "usb" "666"
setup_device_safe "/dev/vser" "dialout" "666"
setup_device_safe "/dev/bus/usb/001/001" "usb" "666"

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
setup_device_safe "/dev/snd/comprC0D4" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D15p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D10c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D49c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D6p" "audio" "666"
setup_device_safe "/dev/snd/comprC0D11" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D13c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D7p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D9c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D3p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D49p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D6c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D17c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D1p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D0c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D53p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D16c" "audio" "666"
setup_device_safe "/dev/snd/timer" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D10p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D2c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D8c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D0p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D12p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D5c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D14c" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D5p" "audio" "666"
setup_device_safe "/dev/snd/pcmC0D1c" "audio" "666"
setup_device_safe "/dev/snd/controlC0" "audio" "666"

# Video/Graphics devices (video group)
setup_device_safe "/dev/dri/card0" "video" "666"
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
setup_device_safe "/dev/input/event0" "input" "666"
setup_device_safe "/dev/input/event1" "input" "666"
setup_device_safe "/dev/input/event2" "input" "666"
setup_device_safe "/dev/input/event3" "input" "666"
setup_device_safe "/dev/input/event4" "input" "666"
setup_device_safe "/dev/input/mice" "input" "666"
setup_device_safe "/dev/uinput" "input" "666"
setup_device_safe "/dev/uhid" "input" "666"
setup_device_safe "/dev/psaux" "input" "666"

# GPIO devices (sys group - system hardware)
setup_device_safe "/dev/gpiochip0" "sys" "666"
setup_device_safe "/dev/gpiochip1" "sys" "666"
setup_device_safe "/dev/gpiochip2" "sys" "666"
setup_device_safe "/dev/gpiochip3" "sys" "666"
setup_device_safe "/dev/gpiochip4" "sys" "666"
setup_device_safe "/dev/gpiochip5" "sys" "666"

# I2C devices (sys group)
setup_device_safe "/dev/i2c-0" "sys" "666"
setup_device_safe "/dev/i2c-1" "sys" "666"
setup_device_safe "/dev/i2c-2" "sys" "666"
setup_device_safe "/dev/i2c-3" "sys" "666"
setup_device_safe "/dev/i2c-4" "sys" "666"
setup_device_safe "/dev/i2c-5" "sys" "666"

# Sensor devices (sys group)
setup_device_safe "/dev/iio:device0" "sys" "666"
setup_device_safe "/dev/iio:device1" "sys" "666"
setup_device_safe "/dev/sprd_sensor" "sys" "666"
setup_device_safe "/dev/sprd_flash" "video" "666"

# RTC device (sys group)
setup_device_safe "/dev/rtc0" "sys" "666"

# Memory devices - handle both static and dynamic ashmem
setup_device_safe "/dev/ashmem" "mem" "666"
setup_device_safe "/dev/ashmem*" "mem" "666"  # Handle UUID-suffixed devices
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

# RetroStation devices (games group)
setup_device_safe "/dev/rscom" "games" "666"
setup_device_safe "/dev/rsinput" "games" "666"
setup_device_safe "/dev/rstouch" "games" "666"

# System log devices (adm group for monitoring)
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
setup_device_safe "/dev/sprd_flash" "sys" "666"
setup_device_safe "/dev/autotest0" "sys" "666"
setup_device_safe "/dev/map_user" "sys" "666"

# System performance/monitoring (adm group)
setup_device_safe "/dev/network_throughput" "adm" "664"
setup_device_safe "/dev/network_latency" "adm" "664"
setup_device_safe "/dev/memory_bandwidth" "adm" "664"
setup_device_safe "/dev/cpu_dma_latency" "adm" "664"
setup_device_safe "/dev/cluster0_core_max" "adm" "664"
setup_device_safe "/dev/cluster0_core_min" "adm" "664"
setup_device_safe "/dev/cluster0_freq_max" "adm" "664"
setup_device_safe "/dev/cluster0_freq_min" "adm" "664"
setup_device_safe "/dev/cluster1_core_max" "adm" "664"
setup_device_safe "/dev/cluster1_core_min" "adm" "664"
setup_device_safe "/dev/cluster1_freq_max" "adm" "664"
setup_device_safe "/dev/cluster1_freq_min" "adm" "664"

# Debug/trace devices (adm group)
setup_device_safe "/dev/tmc_etb" "adm" "664"
setup_device_safe "/dev/etf-3e003000" "adm" "664"
setup_device_safe "/dev/etf-3e002000" "adm" "664"

# Filesystem in userspace
setup_device_safe "/dev/fuse" "users" "666"
setup_device_safe "/dev/cuse" "users" "666"

# TTY and system devices
setup_device_safe "/dev/ptmx" "tty" "666"
setup_device_safe "/dev/kmsg" "adm" "644"
setup_device_safe "/dev/pmsg0" "adm" "664"
setup_device_safe "/dev/device-mapper" "disk" "640"
setup_device_safe "/dev/trusty-ipc-dev0" "sys" "666"
setup_device_safe "/dev/ndctl0" "sys" "666"
setup_device_safe "/dev/pmic" "sys" "666"

# Block devices (disk group)
echo "Setting up block devices..." | tee -a "$LOG_FILE"

# RAM disks
for i in $(seq 0 15); do
    setup_device_safe "/dev/block/ram$i" "disk" "666"
done

# Loop devices
for i in $(seq 0 15); do
    setup_device_safe "/dev/block/loop$i" "disk" "666"
done

# MMC devices - restrictive permissions for critical ones
setup_device_safe "/dev/block/mmcblk0" "disk" "640"
setup_device_safe "/dev/block/mmcblk0boot0" "disk" "640"
setup_device_safe "/dev/block/mmcblk0boot1" "disk" "640"
setup_device_safe "/dev/block/mmcblk0rpmb" "disk" "640"
setup_device_safe "/dev/block/mmcblk1" "disk" "666"
setup_device_safe "/dev/block/mmcblk1p1" "disk" "666"

# MMC partitions - individual setup for existing partitions
for i in $(seq 1 76); do
    setup_device_safe "/dev/block/mmcblk0p$i" "disk" "666"
done

# Special memory devices
setup_device_safe "/dev/block/pmem0" "disk" "666"
setup_device_safe "/dev/block/zram0" "disk" "666"

# By-name symlinks - restrictive for critical system partitions
echo "Setting up by-name partition symlinks..." | tee -a "$LOG_FILE"

# System-critical partitions get restricted access
setup_device_safe "/dev/block/by-name/boot_a" "disk" "640"
setup_device_safe "/dev/block/by-name/boot_b" "disk" "640"
setup_device_safe "/dev/block/by-name/vendor_boot_a" "disk" "640"
setup_device_safe "/dev/block/by-name/vendor_boot_b" "disk" "640"
setup_device_safe "/dev/block/by-name/userdata" "disk" "660"
setup_device_safe "/dev/block/by-name/cache" "disk" "666"

# Other by-name partitions - more permissive
by_name_devices="socko_a socko_b miscdata trustos_a trustos_b vbmeta_vendor_a vbmeta_vendor_b vbmeta_a vbmeta_b odmko_a odmko_b vbmeta_system_ext_a vbmeta_system_ext_b uboot_a uboot_b mmcblk0boot1 mmcblk0boot0 avbmeta_rs_a avbmeta_rs_b common_rs1_a common_rs1_b l_agdsp_a l_agdsp_b metadata common_rs2_a common_rs2_b l_gdsp_a l_gdsp_b l_cdsp_a l_cdsp_b prodnv pm_sys_a pm_sys_b teecfg_a teecfg_b vbmeta_product_a vbmeta_product_b logo misc wcnmodem_a wcnmodem_b l_ldsp_b l_ldsp_a vbmeta_system_b vbmeta_system_a l_fixnv2_a l_fixnv2_b l_modem_a l_modem_b l_deltanv_a l_deltanv_b l_runtimenv2 l_runtimenv1 sml_a sml_b vbmeta_odm_a vbmeta_odm_b gnssmodem_a gnssmodem_b persist sysdumpdb dtbo_a dtbo_b l_fixnv1_a l_fixnv1_b dtb_a dtb_b hypervsior_b hypervsior_a super uboot_log fbootlogo mmcblk0"

for device in $by_name_devices; do
    setup_device_safe "/dev/block/by-name/$device" "disk" "666"
done

# Platform-specific device paths - handle individually to avoid wildcard issues
echo "Setting up platform-specific device paths..." | tee -a "$LOG_FILE"

# Platform paths for mmcblk0 partitions
for i in $(seq 1 76); do
    setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71400000.sdio/mmcblk0p$i" "disk" "666"
done

# Platform paths for boot partitions
setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71400000.sdio/mmcblk0boot0" "disk" "640"
setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71400000.sdio/mmcblk0boot1" "disk" "640"
setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71400000.sdio/mmcblk0" "disk" "640"

# Platform paths for other devices
setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71100000.sdio/mmcblk1p1" "disk" "666"
setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71100000.sdio/mmcblk1" "disk" "666"
setup_device_safe "/dev/block/platform/81ff0000.rebootescrow/pmem0" "disk" "666"

# Platform by-name paths for key devices
for device in $by_name_devices; do
    setup_device_safe "/dev/block/platform/soc/soc:ap-apb/71400000.sdio/by-name/$device" "disk" "666"
done

# Audio DSP devices
setup_device_safe "/dev/audio_dsp*" "audio" "666"
setup_device_safe "/dev/audio_pipe*" "audio" "660"

# GNSS devices
setup_device_safe "/dev/sttygnss0" "sys" "660"
setup_device_safe "/dev/spipe_gnss0" "sys" "660"
setup_device_safe "/dev/spipe_gnss1" "sys" "660"

# Bluetooth devices
setup_device_safe "/dev/ttyM0" "bluetooth" "660"
setup_device_safe "/dev/ttyM1" "bluetooth" "660"
setup_device_safe "/dev/sttybt0" "bluetooth" "660"

# LTE/Radio devices (wildcards handled)
setup_device_safe "/dev/stty_lte*" "sys" "660"
setup_device_safe "/dev/spipe_lte5" "sys" "660"
setup_device_safe "/dev/spipe_lte4" "audio" "660"
setup_device_safe "/dev/spipe_lte6" "audio" "660"
setup_device_safe "/dev/spipe_lte9" "dialout" "660"
setup_device_safe "/dev/spipe_lte14" "audio" "660"
setup_device_safe "/dev/spipe_pm*" "sys" "666"

# Camera/ISP devices
setup_device_safe "/dev/vdsp*" "sys" "660"
setup_device_safe "/dev/sprd_jpg1" "video" "660"
setup_device_safe "/dev/sprd_vpp" "video" "660"
setup_device_safe "/dev/sprd_vsp_enc" "video" "660"
setup_device_safe "/dev/sprd_image" "video" "660"
setup_device_safe "/dev/sprd_isp" "video" "660"
setup_device_safe "/dev/sprd_fd" "video" "660"

# Graphics devices
setup_device_safe "/dev/pvr_sync" "video" "666"
setup_device_safe "/dev/dri/*" "video" "666"
setup_device_safe "/dev/graphics/*" "video" "660"

# Block/Storage devices from ueventd
setup_device_safe "/dev/block/by-name/l_agdsp" "audio" "660"
setup_device_safe "/dev/block/by-name/l_*" "sys" "660"
setup_device_safe "/dev/block/by-name/pm_sys*" "sys" "660"
setup_device_safe "/dev/block/mmcblk1p*" "sys" "660"
setup_device_safe "/dev/mmcblk0rpmb" "sys" "660"
setup_device_safe "/dev/block/memdisk0p1" "sys" "770"

# Input devices (wildcards)
setup_device_safe "/dev/input/event*" "input" "660"
setup_device_safe "/dev/v4l-touch*" "input" "660"
setup_device_safe "/dev/input/*" "input" "660"

# USB devices (wildcards)
setup_device_safe "/dev/bus/usb/*" "usb" "660"

# System devices
setup_device_safe "/dev/ttyS3" "sys" "660"
setup_device_safe "/dev/ttyS4" "sys" "660"
setup_device_safe "/dev/power_ctl" "sys" "660"
setup_device_safe "/dev/ttyGS*" "sys" "660"
setup_device_safe "/dev/iio:device*" "sys" "660"
setup_device_safe "/dev/rtc*" "sys" "660"
setup_device_safe "/dev/hw_random" "sys" "440"
setup_device_safe "/dev/tty0" "sys" "660"

# Binder IPC devices
setup_device_safe "/dev/binder" "root" "666"
setup_device_safe "/dev/hwbinder" "root" "666"
setup_device_safe "/dev/vndbinder" "root" "666"

# Add current user to essential device access groups
echo "Adding $CURRENT_USER to essential device access groups..." | tee -a "$LOG_FILE"

essential_groups="disk dialout audio video input netdev sys adm users wheel bluetooth graphics log usb mtp"
for group in $essential_groups; do
    add_user_to_group_safe "$CURRENT_USER" "$group"
done

# Final status report using POSIX-compatible grep
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

# Enhanced group display using POSIX-compatible grep
echo "Current groups for user $CURRENT_USER:" | tee -a "$LOG_FILE"
if [ -f "/etc/group" ]; then
    # POSIX-compatible: find groups containing the user
    user_groups=$(grep ":${CURRENT_USER}" /etc/group 2>/dev/null | cut -d: -f1 | tr '\n' ' ')
    if [ -n "$user_groups" ]; then
        echo "$user_groups" | tee -a "$LOG_FILE"
    else
        echo "No groups found for user $CURRENT_USER" | tee -a "$LOG_FILE"
    fi
else
    echo "Unable to display groups - /etc/group not accessible" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "Setup complete. Please log out and log back in for group changes to take effect." | tee -a "$LOG_FILE"
echo "Run 'cat $LOG_FILE' to review the complete setup log." | tee -a "$LOG_FILE"
