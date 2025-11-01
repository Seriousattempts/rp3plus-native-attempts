#!/bin/bash

# Debian 13 (Trixie) Automation Setup Script for UNISOC Hardware

echo "=== Debian 13 (Trixie) UNISOC Hardware Setup Script ==="
echo "Starting setup at $(date)"

# Variables
LINUXDATA_PARTITION="/dev/block/mmcblk0p77"
MOUNT_POINT="/data/linuxdata"
CHROOT_PATH="$MOUNT_POINT/debian-chroot"
DEBIAN_RELEASE="trixie"
DEBIAN_ARCH="arm64"
WORK_DIR="/data/local/tmp"

# Debian Trixie rootfs from proot-distro
ROOTFS_VERSION="v4.29.0"
ROOTFS_URL="https://github.com/termux/proot-distro/releases/download/${ROOTFS_VERSION}/debian-${DEBIAN_RELEASE}-aarch64-pd-${ROOTFS_VERSION}.tar.xz"

detect_sdcard_path() {
    echo "=== Auto-detecting SD card path ==="
    SDCARD_PATHS=$(ls -d /storage/*-* 2>/dev/null | head -1)
    if [ -z "$SDCARD_PATHS" ]; then
        for path in "/storage/emulated/0" "/sdcard" "/storage/sdcard1"; do
            if [ -d "$path" ] && [ -w "$path" ]; then
                SDCARD_PATHS="$path"
                break
            fi
        done
    fi
    if [ -z "$SDCARD_PATHS" ]; then
        LOG_PATH="/data/debian_setup.log"
        SCRIPT_BASE="/data"
    else
        LOG_PATH="$SDCARD_PATHS/debian_setup.log"
        SCRIPT_BASE="$SDCARD_PATHS"
    fi
}

log_message() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] $message" | tee -a "$LOG_PATH"
}

log_execute() {
    local command="$1"
    log_message "EXECUTING: $command"
    if eval "$command" >> "$LOG_PATH" 2>&1; then
        log_message "SUCCESS"
        return 0
    else
        local exit_code=$?
        log_message "WARNING: exit code $exit_code"
        return $exit_code
    fi
}

check_root() {
    log_message "=== Checking root access ==="
    if [ "$(id -u)" != "0" ]; then
        log_message "ERROR: Must run as root"
        exit 1
    fi
    log_message "✓ Running as root (UID: $(id -u))"
}

verify_helper_scripts() {
    log_message "=== Verifying helper scripts ==="
    local all_found=true
    for script in setup-unisoc-hardware.sh install-unisoc-service.sh dev-nodes.sh; do
        if [ -f "$SCRIPT_BASE/$script" ]; then
            log_message "✓ Found: $script"
        else
            log_message "⚠ WARNING: $script not found"
            all_found=false
        fi
    done
    
    if [ -f "$SCRIPT_BASE/install_packages.sh" ]; then
        log_message "✓ Found: install_packages.sh"
    else
        log_message "⚠ WARNING: install_packages.sh not found (package installation will be skipped)"
    fi
    
    if [ "$all_found" = false ]; then
        log_message "WARNING: Some helper scripts missing (continuing anyway)"
    fi
    log_message "✓ Helper script verification complete"
}

setup_work_directory() {
    log_message "=== Setting up working directory ==="
    mkdir -p "$WORK_DIR" >> "$LOG_PATH" 2>&1
    chmod 777 "$WORK_DIR" >> "$LOG_PATH" 2>&1
    log_message "✓ Working directory ready"
}

mount_linuxdata() {
    log_message "=== Mounting linuxdata partition ==="
    mkdir -p "$MOUNT_POINT" 2>/dev/null
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null || mount | grep -q "$MOUNT_POINT"; then
        log_message "✓ Already mounted"
    else
        if mount -t ext4 "$LINUXDATA_PARTITION" "$MOUNT_POINT" || mount "$LINUXDATA_PARTITION" "$MOUNT_POINT"; then
            log_message "✓ Mounted successfully"
        else
            log_message "ERROR: Mount failed"
            exit 1
        fi
    fi
    log_execute "df -h '$MOUNT_POINT'"
}

setup_chroot_environment() {
    log_message "=== Setting up Debian chroot environment ==="
    mkdir -p "$CHROOT_PATH" 2>/dev/null
    log_message "Debian will be installed to: $CHROOT_PATH"
}

install_debian_rootfs() {
    log_message "=== Installing Debian 13 (Trixie) rootfs ==="

    if [ -f "$CHROOT_PATH/bin/bash" ] && [ -d "$CHROOT_PATH/etc" ]; then
        log_message "ℹ Debian already installed"
        setup_bind_mounts
        setup_chroot_system_environment
        bind_android_partitions
        configure_dns
        make_data_writable
        return 0
    fi

    local file_count=$(find "$CHROOT_PATH" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    if [ "$file_count" -gt 0 ] && [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        log_message "⚠ Cleaning incomplete installation"
        rm -rf "$CHROOT_PATH"/* 2>/dev/null
    fi

    local rootfs_file="$WORK_DIR/debian-${DEBIAN_RELEASE}-aarch64.tar.xz"
    
    log_message "Downloading rootfs (~35MB, 1-5 min)..."
    if command -v wget >/dev/null 2>&1; then
        wget -O "$rootfs_file" "$ROOTFS_URL" 2>&1 | tee -a "$LOG_PATH"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$rootfs_file" "$ROOTFS_URL" 2>&1 | tee -a "$LOG_PATH"
    else
        log_message "ERROR: No download tool"
        return 1
    fi

    log_message "✓ Downloaded ($(ls -lh $rootfs_file | awk '{print $5}'))"

    log_message "Extracting rootfs (2-5 min)..."
    local temp_extract="$WORK_DIR/debian_extract_temp"
    rm -rf "$temp_extract" 2>/dev/null
    mkdir -p "$temp_extract"
    
    if xz -dc "$rootfs_file" 2>> "$LOG_PATH" | tar -xf - -C "$temp_extract" 2>> "$LOG_PATH"; then
        log_message "✓ Extracted to temp"
    else
        log_message "ERROR: Extraction failed"
        rm -rf "$temp_extract" "$rootfs_file"
        return 1
    fi

    local extracted_dir=$(find "$temp_extract" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$extracted_dir" ]; then
        log_message "ERROR: No subdirectory found"
        rm -rf "$temp_extract" "$rootfs_file"
        return 1
    fi
    
    if mv "$extracted_dir"/* "$CHROOT_PATH/" 2>> "$LOG_PATH"; then
        log_message "✓ Moved files to chroot"
    else
        log_message "ERROR: Move failed"
        rm -rf "$temp_extract" "$rootfs_file"
        return 1
    fi

    rm -rf "$temp_extract" "$rootfs_file"
    log_message "✓ Cleanup complete"

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        log_message "ERROR: /bin/bash missing"
        return 1
    fi
    log_message "✓ Debian verified ($(du -sh $CHROOT_PATH | awk '{print $1}'))"

    setup_bind_mounts
    setup_chroot_system_environment
    bind_android_partitions
    configure_dns
    make_data_writable
    log_message "✓ Debian installation complete"
}

configure_dns() {
    log_message "=== Configuring DNS ==="
    cat > "$CHROOT_PATH/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    log_message "✓ DNS configured (1.1.1.1, 8.8.8.8)"
}

make_data_writable() {
    log_message "=== Making /data writable from chroot ==="
    mkdir -p "$CHROOT_PATH/data" 2>/dev/null
    if ! mount | grep -q "$CHROOT_PATH/data "; then
        if mount --bind /data "$CHROOT_PATH/data" 2>/dev/null; then
            log_message "✓ Bind-mounted /data to chroot"
        else
            log_message "⚠ Failed to bind-mount /data"
        fi
    else
        log_message "✓ /data already bind-mounted"
    fi
}

setup_chroot_system_environment() {
    log_message "=== Setting up chroot environment ==="
    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        return 0
    fi
    mkdir -p "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/tmp" "$CHROOT_PATH/tmp/runtime" 2>/dev/null
    chmod 1777 "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/tmp" "$CHROOT_PATH/tmp/runtime" 2>/dev/null
    for dev in null zero full random urandom fuse tty ptmx; do
        [ -e "$CHROOT_PATH/dev/$dev" ] && chmod 666 "$CHROOT_PATH/dev/$dev" 2>/dev/null
    done
    log_message "✓ Environment configured"
}

bind_android_partitions() {
    log_message "=== Bind-mounting Android partitions ==="
    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        return 0
    fi
    for partition in system system_ext vendor product; do
        mkdir -p "$CHROOT_PATH/$partition" 2>/dev/null
        if [ -d "/$partition" ] && ! mount | grep -q "$CHROOT_PATH/$partition"; then
            mount --bind /$partition "$CHROOT_PATH/$partition" 2>/dev/null && log_message "✓ Mounted /$partition"
        fi
    done
}

setup_bind_mounts() {
    log_message "Setting up bind mounts..."
    ! mount | grep -q "$CHROOT_PATH/dev " && mount --bind /dev "$CHROOT_PATH/dev" 2>/dev/null
    ! mount | grep -q "$CHROOT_PATH/proc" && mount -t proc proc "$CHROOT_PATH/proc" 2>/dev/null
    ! mount | grep -q "$CHROOT_PATH/sys" && mount -t sysfs sysfs "$CHROOT_PATH/sys" 2>/dev/null
    mkdir -p "$CHROOT_PATH/dev/pts" 2>/dev/null
    ! mount | grep -q "$CHROOT_PATH/dev/pts" && mount -t devpts devpts "$CHROOT_PATH/dev/pts" 2>/dev/null
    log_message "✓ Bind mounts ready"
}

chroot_exec() {
    if [ -f "$CHROOT_PATH/bin/bash" ]; then
        chroot "$CHROOT_PATH" /usr/bin/env -i \
            PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            TERM="$TERM" \
            HOME=/root \
            /bin/bash -c "$1"
    else
        log_message "⚠ Cannot chroot: bash missing"
        return 1
    fi
}

install_hardware_packages() {
    log_message "=== Installing comprehensive hardware support packages ==="

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        log_message "ERROR: Debian installation incomplete"
        return 1
    fi

    # FIXED: Plain URLs without Markdown syntax
    log_message "Configuring apt sources..."
    cat > "$CHROOT_PATH/etc/apt/sources.list" << 'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
    log_message "✓ Configured apt sources"

    local install_script="$SCRIPT_BASE/install_packages.sh"
    if [ ! -f "$install_script" ]; then
        log_message "WARNING: install_packages.sh not found"
        log_message "Skipping package installation"
        return 0
    fi

    log_message "Transferring install_packages.sh to Debian /root..."
    cp "$install_script" "$CHROOT_PATH/root/install_packages.sh"
    chmod +x "$CHROOT_PATH/root/install_packages.sh"
    log_message "✓ Script transferred"

    log_message "Updating package lists..."
    # FIXED: Removed tee to prevent duplicate logging
    if chroot_exec "apt-get update" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Package lists updated"
    else
        log_message "⚠ Package list update had warnings"
    fi

    log_message "Executing package installation (10-30 minutes)..."
    log_message "Monitor: tail -f $LOG_PATH"

    # FIXED: Removed tee to prevent duplicate logging
    if chroot_exec "/bin/bash /root/install_packages.sh" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Package installation completed"
    else
        log_message "⚠ Package installation had warnings"
    fi

    log_message "✓ Hardware packages installation process completed"
}

copy_package_log_to_sdcard() {
    log_message "=== Copying package installation log to SD card ==="
    
    if [ -f "$CHROOT_PATH/data/package_install.log" ]; then
        if cp "$CHROOT_PATH/data/package_install.log" "$SDCARD_PATHS/package_install.log" 2>/dev/null; then
            log_message "✓ Package log copied to $SDCARD_PATHS/package_install.log"
        else
            log_message "⚠ Failed to copy package log to SD card"
        fi
    else
        log_message "ℹ No package installation log found at $CHROOT_PATH/data/package_install.log"
    fi
}

install_unisoc_hardware_and_service() {
    log_message "=== Installing UNISOC Hardware ==="

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        log_message "ERROR: Debian not installed"
        return 1
    fi

    if [ -f "$SCRIPT_BASE/setup-unisoc-hardware.sh" ]; then
        mkdir -p "$CHROOT_PATH/usr/local/bin"
        cp "$SCRIPT_BASE/setup-unisoc-hardware.sh" "$CHROOT_PATH/usr/local/bin/setup-unisoc-hardware"
        chmod +x "$CHROOT_PATH/usr/local/bin/setup-unisoc-hardware"
        log_message "✓ UNISOC hardware script installed"
    else
        log_message "⚠ setup-unisoc-hardware.sh not found"
    fi
    
    if [ -f "$SCRIPT_BASE/install-unisoc-service.sh" ]; then
        cp "$SCRIPT_BASE/install-unisoc-service.sh" "$CHROOT_PATH/root/install-unisoc-service.sh"
        chmod +x "$CHROOT_PATH/root/install-unisoc-service.sh"
        
        log_message "Installing UNISOC service..."
        if chroot_exec "/bin/bash /root/install-unisoc-service.sh" >> "$LOG_PATH" 2>&1; then
            log_message "✓ UNISOC service installed"
        else
            log_message "⚠ UNISOC service installation had warnings"
        fi
    else
        log_message "⚠ install-unisoc-service.sh not found"
    fi
}

copy_unisoc_log_to_sdcard() {
    log_message "=== Copying UNISOC hardware log to SD card ==="
    
    if [ -f "$CHROOT_PATH/var/log/unisoc-hardware.log" ]; then
        if cp "$CHROOT_PATH/var/log/unisoc-hardware.log" "$SDCARD_PATHS/unisoc-hardware.log" 2>/dev/null; then
            log_message "✓ UNISOC hardware log copied to $SDCARD_PATHS/unisoc-hardware.log"
        else
            log_message "⚠ Failed to copy UNISOC log to SD card"
        fi
    else
        log_message "ℹ No UNISOC hardware log found"
    fi
}

create_default_user() {
    log_message "=== Creating user p3plus ==="

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        return 1
    fi

    if chroot_exec "/usr/bin/id p3plus 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "ℹ User exists"
        return 0
    fi

    chroot_exec "useradd -m -s /bin/bash p3plus" >> "$LOG_PATH" 2>&1
    log_message "✓ User created"

    local groups="root bin daemon sys adm tty disk lp mem kmem wheel floppy mail news uucp man cron console audio cdrom dialout ftp sshd at tape video netdev readproc squid gdm xfs kvm games named mysql postgres cdrw apache nut usb avahi vpopmail users ntp nofiles qmail postfix postdrop smmsp slocate abuild utmp nogroup nobody"
    
    log_message "Adding user to groups..."
    for group in $groups; do
        chroot_exec "groupadd $group 2>/dev/null; usermod -a -G $group p3plus 2>/dev/null" >> "$LOG_PATH" 2>&1
    done
    log_message "✓ Groups assigned"

    mkdir -p "$CHROOT_PATH/etc/sudoers.d" 2>/dev/null
    echo 'p3plus ALL=(ALL) NOPASSWD: ALL' > "$CHROOT_PATH/etc/sudoers.d/p3plus"
    chmod 0440 "$CHROOT_PATH/etc/sudoers.d/p3plus" 2>/dev/null
    
    log_message "✓ User configured"
}

copy_droid_folder() {
    log_message "=== Copying droid folder ==="

    local source_droid="$SDCARD_PATHS/droid"
    local dest_droid="$CHROOT_PATH/home/p3plus/droid"

    if [ ! -d "$source_droid" ]; then
        log_message "⚠ droid folder not found"
        return 0
    fi

    rm -rf "$dest_droid" 2>/dev/null
    
    if cp -r "$source_droid" "$dest_droid" 2>/dev/null; then
        chroot_exec "/usr/bin/chown -R p3plus:p3plus /home/p3plus/droid 2>/dev/null" >> "$LOG_PATH" 2>&1
        log_message "✓ droid folder copied"
    fi
}

run_device_nodes_setup() {
    log_message "=== Running device nodes setup ==="

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        return 1
    fi

    if [ ! -f "$SCRIPT_BASE/dev-nodes.sh" ]; then
        log_message "⚠ dev-nodes.sh not found"
        return 0
    fi

    cp "$SCRIPT_BASE/dev-nodes.sh" "$CHROOT_PATH/tmp/dev-nodes.sh"
    chmod +x "$CHROOT_PATH/tmp/dev-nodes.sh"

    log_message "Executing dev-nodes.sh..."
    if chroot_exec "SD_MOUNT='$SDCARD_PATHS' USER=p3plus /bin/bash /tmp/dev-nodes.sh" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Device setup completed"
    else
        log_message "⚠ Device setup had warnings"
    fi

    rm -f "$CHROOT_PATH/tmp/dev-nodes.sh"
}

test_installation() {
    log_message "=== Testing installation ==="

    if [ ! -f "$CHROOT_PATH/bin/bash" ]; then
        log_message "ERROR: Cannot test"
        return 1
    fi

    chroot_exec "echo 'Chroot test successful'" >> "$LOG_PATH" 2>&1 && log_message "✓ Chroot works"
    [ -x "$CHROOT_PATH/usr/local/bin/setup-unisoc-hardware" ] && log_message "✓ UNISOC script exists"
    chroot_exec "echo 'test' > /dev/null" >> "$LOG_PATH" 2>&1 && log_message "✓ /dev/null works"
    chroot_exec "/usr/bin/id p3plus 2>/dev/null" >> "$LOG_PATH" 2>&1 && log_message "✓ User p3plus exists"
    
    if chroot_exec "cat /etc/resolv.conf" >> "$LOG_PATH" 2>&1; then
        log_message "✓ DNS configured"
    fi
    
    if chroot_exec "touch /data/test_write && rm /data/test_write" >> "$LOG_PATH" 2>&1; then
        log_message "✓ /data is writable"
    fi
    
    log_message "✓ Testing completed"
}

create_mount_script() {
    log_message "=== Creating persistent mount script ==="
    mkdir -p "/data/adb/service.d" 2>/dev/null

    cat << 'MOUNT_SCRIPT' > /data/adb/service.d/debian-mount.sh
#!/system/bin/sh
SCRIPT_LOG="/data/adb/debian-mount.log"
echo "$(date): Starting" >> "$SCRIPT_LOG"
sleep 30
LINUXDATA_PARTITION="/dev/block/mmcblk0p77"
MOUNT_POINT="/data/linuxdata"
CHROOT_PATH="$MOUNT_POINT/debian-chroot"
mkdir -p "$MOUNT_POINT" >> "$SCRIPT_LOG" 2>&1
if ! mount | grep -q "$MOUNT_POINT"; then
    mount -t ext4 "$LINUXDATA_PARTITION" "$MOUNT_POINT" >> "$SCRIPT_LOG" 2>&1
fi
if [ -f "$CHROOT_PATH/bin/bash" ]; then
    mkdir -p "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/tmp" "$CHROOT_PATH/tmp/runtime" "$CHROOT_PATH/data" 2>/dev/null
    chmod 1777 "$CHROOT_PATH/dev/shm" "$CHROOT_PATH/tmp" "$CHROOT_PATH/tmp/runtime" 2>/dev/null
    for dev in null zero full random urandom fuse tty ptmx; do
        chmod 666 "$CHROOT_PATH/dev/$dev" 2>/dev/null
    done
    if ! mount | grep -q "$CHROOT_PATH/dev "; then
        mount --bind /dev "$CHROOT_PATH/dev" 2>/dev/null
        mount -t proc proc "$CHROOT_PATH/proc" 2>/dev/null
        mount -t sysfs sysfs "$CHROOT_PATH/sys" 2>/dev/null
        mount -t devpts devpts "$CHROOT_PATH/dev/pts" 2>/dev/null
    fi
    for dir in system system_ext vendor product data; do
        mkdir -p "$CHROOT_PATH/$dir" 2>/dev/null
        if [ -d "/$dir" ] && ! mount | grep -q "$CHROOT_PATH/$dir"; then
            mount --bind /$dir "$CHROOT_PATH/$dir" 2>/dev/null
        fi
    done
fi
echo "$(date): Complete" >> "$SCRIPT_LOG"
MOUNT_SCRIPT

    chmod +x /data/adb/service.d/debian-mount.sh
    log_message "✓ Persistent mount script created"
}

main() {
    detect_sdcard_path

    log_message "=== Debian 13 (Trixie) Setup with UNISOC Hardware ==="
    log_message "Process ID: $$"

    check_root
    setup_work_directory
    verify_helper_scripts
    mount_linuxdata  
    setup_chroot_environment
    install_debian_rootfs
    
    if [ -f "$CHROOT_PATH/bin/bash" ]; then
        install_hardware_packages
        copy_package_log_to_sdcard      # NEW: Copy package log to SD card
        install_unisoc_hardware_and_service
        copy_unisoc_log_to_sdcard
        create_default_user
        copy_droid_folder
        run_device_nodes_setup
        test_installation
    else
        log_message "ERROR: Debian installation failed"
    fi
    
    create_mount_script

    log_message ""
    log_message "=== Setup Complete ==="
    log_message "Debian: $CHROOT_PATH"
    log_message "Log: $LOG_PATH"
    
    [ "$LOG_PATH" != "/data/debian_setup.log" ] && cp "$LOG_PATH" "/data/debian_setup_backup.log" 2>/dev/null
    
    log_message ""
    log_message "To enter Debian:"
    log_message "  chroot $CHROOT_PATH /bin/bash"
    log_message "Or as p3plus:"
    log_message "  chroot $CHROOT_PATH /bin/su - p3plus"
}

main "$@"
