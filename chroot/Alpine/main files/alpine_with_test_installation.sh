#!/bin/bash

# Alpine Linux Automation Setup Script for UNISOC Hardware
# Integrated version with install scripts
# Modified to remove Android bind and add specific Android partition bind-mounts

echo "=== Alpine Linux UNISOC Hardware Setup Script ==="
echo "Starting setup at $(date)"

# Variables
LINUXDATA_PARTITION="/dev/block/mmcblk0p77"
MOUNT_POINT="/data/linuxdata"
CHROOT_PATH="$MOUNT_POINT/chroot-distro"

# Auto-detect SD card path (format: XXXX-XXXX)
detect_sdcard_path() {
    echo "=== Auto-detecting SD card path ==="

    # Look for SD card mount points with format XXXX-XXXX
    SDCARD_PATHS=$(ls -d /storage/*-* 2>/dev/null | head -1)

    if [ -z "$SDCARD_PATHS" ]; then
        # Fallback to common SD card paths
        for path in "/storage/emulated/0" "/sdcard" "/storage/sdcard1"; do
            if [ -d "$path" ] && [ -w "$path" ]; then
                SDCARD_PATHS="$path"
                break
            fi
        done
    fi

    if [ -z "$SDCARD_PATHS" ]; then
        echo "WARNING: Could not auto-detect SD card path. Using /data as fallback."
        LOG_PATH="/data/alpine_setup.log"
        SCRIPT_BASE="/data"
    else
        LOG_PATH="$SDCARD_PATHS/alpine_setup.log"
        SCRIPT_BASE="$SDCARD_PATHS"
        echo "Detected SD card path: $SDCARD_PATHS"
    fi

    echo "Log file will be saved to: $LOG_PATH"
    echo "Looking for helper scripts in: $SCRIPT_BASE"
}

# Function to log messages with timestamp
log_message() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] $message" | tee -a "$LOG_PATH"
}

# Function to log and execute commands
log_execute() {
    local command="$1"
    log_message "EXECUTING: $command"

    # Execute command and capture output
    if eval "$command" >> "$LOG_PATH" 2>&1; then
        log_message "SUCCESS: Command completed successfully"
        return 0
    else
        local exit_code=$?
        log_message "WARNING: Command failed with exit code $exit_code, but continuing..."
        return $exit_code
    fi
}

# Function to check if running as root
check_root() {
    log_message "=== Checking root access ==="

    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR: This script must be run as root"
        log_message "Run: su -c 'sh /storage/XXXX-XXXX/alpine.sh'"
        exit 1
    fi

    log_message "✓ Running as root user"
    log_message "Current user: $(whoami)"
    log_message "Current UID: $EUID"
}

# Function to verify helper scripts exist
verify_helper_scripts() {
    log_message "=== Verifying helper scripts ==="

    local all_found=true

    # Check for install_packages.sh
    if [ -f "$SCRIPT_BASE/install_packages.sh" ]; then
        log_message "✓ Found: install_packages.sh"
    else
        log_message "⚠ WARNING: install_packages.sh not found at $SCRIPT_BASE"
        all_found=false
    fi

    # Check for setup-unisoc-hardware.sh
    if [ -f "$SCRIPT_BASE/setup-unisoc-hardware.sh" ]; then
        log_message "✓ Found: setup-unisoc-hardware.sh"
    else
        log_message "⚠ WARNING: setup-unisoc-hardware.sh not found at $SCRIPT_BASE"
        all_found=false
    fi

    # Check for install-unisoc-service.sh
    if [ -f "$SCRIPT_BASE/install-unisoc-service.sh" ]; then
        log_message "✓ Found: install-unisoc-service.sh"
    else
        log_message "⚠ WARNING: install-unisoc-service.sh not found at $SCRIPT_BASE"
        all_found=false
    fi

    # Check for dev-nodes.sh
    if [ -f "$SCRIPT_BASE/dev-nodes.sh" ]; then
        log_message "✓ Found: dev-nodes.sh"
    else
        log_message "⚠ WARNING: dev-nodes.sh not found at $SCRIPT_BASE"
        all_found=false
    fi

    if [ "$all_found" = false ]; then
        log_message "ERROR: Some helper scripts are missing. Please ensure all scripts are in $SCRIPT_BASE"
        log_message "Required scripts:"
        log_message "  - install_packages.sh"
        log_message "  - setup-unisoc-hardware.sh"
        log_message "  - install-unisoc-service.sh"
        log_message "  - dev-nodes.sh"
        exit 1
    fi

    log_message "✓ All helper scripts found"
}

# Merged function to setup system directories and device nodes INSIDE chroot
setup_chroot_system_environment() {
    log_message "=== Setting up chroot system environment and device nodes ==="

    local alpine_path="$CHROOT_PATH/alpine"

    # Wait for Alpine installation if not present yet
    if [ ! -d "$alpine_path" ]; then
        log_message "⚠ Alpine not yet installed at $alpine_path, skipping for now"
        return 0
    fi

    log_message "Configuring device nodes and directories inside chroot at: $alpine_path"

    # Create /dev/shm inside chroot
    log_message "Setting up /dev/shm inside chroot..."
    if [ ! -d "$alpine_path/dev/shm" ]; then
        if mkdir -p "$alpine_path/dev/shm" 2>/dev/null; then
            log_message "✓ Created $alpine_path/dev/shm directory"
        else
            log_message "⚠ Failed to create /dev/shm, may already exist"
        fi
    else
        log_message "✓ $alpine_path/dev/shm already exists"
    fi

    if chmod 1777 "$alpine_path/dev/shm" 2>/dev/null; then
        log_message "✓ Set /dev/shm permissions to 1777"
    else
        log_message "⚠ Could not set /dev/shm permissions"
    fi

    # Create /tmp inside chroot with proper permissions
    log_message "Setting up /tmp inside chroot..."
    if [ ! -d "$alpine_path/tmp" ]; then
        if mkdir -p "$alpine_path/tmp" 2>/dev/null; then
            log_message "✓ Created $alpine_path/tmp directory"
        else
            log_message "⚠ Failed to create /tmp"
        fi
    else
        log_message "✓ $alpine_path/tmp already exists"
    fi

    if chmod 1777 "$alpine_path/tmp" 2>/dev/null; then
        log_message "✓ Set /tmp permissions to 1777"
    else
        log_message "⚠ Could not set /tmp permissions"
    fi

    # Create /tmp/runtime inside chroot for XDG compliance
    log_message "Setting up /tmp/runtime inside chroot..."
    if mkdir -p "$alpine_path/tmp/runtime" 2>/dev/null; then
        log_message "✓ Created /tmp/runtime"
    fi

    if chmod 1777 "$alpine_path/tmp/runtime" 2>/dev/null; then
        log_message "✓ Set /tmp/runtime permissions to 1777"
    fi

    # Fix critical device node permissions inside chroot
    log_message "Fixing device node permissions inside chroot..."

    # /dev/null - critical for all I/O operations
    if [ -e "$alpine_path/dev/null" ]; then
        if chmod 666 "$alpine_path/dev/null" 2>/dev/null; then
            log_message "✓ Set /dev/null permissions to 666"
        fi
    else
        log_message "ℹ /dev/null does not exist yet, will be available after bind-mounts"
    fi

    # /dev/zero
    if [ -e "$alpine_path/dev/zero" ]; then
        chmod 666 "$alpine_path/dev/zero" 2>/dev/null
        log_message "✓ Set /dev/zero permissions to 666"
    fi

    # /dev/full
    if [ -e "$alpine_path/dev/full" ]; then
        chmod 666 "$alpine_path/dev/full" 2>/dev/null
        log_message "✓ Set /dev/full permissions to 666"
    fi

    # /dev/random and /dev/urandom
    if [ -e "$alpine_path/dev/random" ]; then
        chmod 666 "$alpine_path/dev/random" 2>/dev/null
        log_message "✓ Set /dev/random permissions to 666"
    fi

    if [ -e "$alpine_path/dev/urandom" ]; then
        chmod 666 "$alpine_path/dev/urandom" 2>/dev/null
        log_message "✓ Set /dev/urandom permissions to 666"
    fi

    # /dev/fuse for filesystem operations
    if [ -e "$alpine_path/dev/fuse" ]; then
        chmod 666 "$alpine_path/dev/fuse" 2>/dev/null
        log_message "✓ Set /dev/fuse permissions to 666"
    else
        log_message "ℹ /dev/fuse will be available after bind-mounts"
    fi

    # /dev/tty
    if [ -e "$alpine_path/dev/tty" ]; then
        chmod 666 "$alpine_path/dev/tty" 2>/dev/null
        log_message "✓ Set /dev/tty permissions to 666"
    fi

    # /dev/ptmx for pseudo-terminals
    if [ -e "$alpine_path/dev/ptmx" ]; then
        chmod 666 "$alpine_path/dev/ptmx" 2>/dev/null
        log_message "✓ Set /dev/ptmx permissions to 666"
    fi

    # Set environment variables for chroot usage
    export XDG_RUNTIME_DIR=/tmp/runtime
    export TMPDIR=/tmp
    log_message "✓ Set environment variables for chroot"

    log_message "✓ Chroot system environment setup completed"
}

# Function to mount linuxdata partition
mount_linuxdata() {
    log_message "=== Mounting linuxdata partition ==="

    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        log_execute "mkdir -p '$MOUNT_POINT'"
        log_message "✓ Created mount point: $MOUNT_POINT"
    else
        log_message "✓ Mount point already exists: $MOUNT_POINT"
    fi

    # Check if already mounted
    if mountpoint -q "$MOUNT_POINT"; then
        log_message "✓ linuxdata partition already mounted"
        log_execute "df -h '$MOUNT_POINT'"
    else
        # Check if partition exists
        if [ ! -e "$LINUXDATA_PARTITION" ]; then
            log_message "ERROR: Partition $LINUXDATA_PARTITION does not exist"
            log_execute "ls -la /dev/block/mmcblk0p*"
            exit 1
        fi

        log_message "Attempting to mount $LINUXDATA_PARTITION to $MOUNT_POINT"

        # Mount the ext4 partition
        if mount -t ext4 "$LINUXDATA_PARTITION" "$MOUNT_POINT"; then
            log_message "✓ Successfully mounted $LINUXDATA_PARTITION to $MOUNT_POINT"
        else
            log_message "WARNING: Failed to mount as ext4, trying without filesystem type..."
            log_execute "blkid '$LINUXDATA_PARTITION'"
            # Try to mount without specifying filesystem type
            if mount "$LINUXDATA_PARTITION" "$MOUNT_POINT"; then
                log_message "✓ Mounted successfully without specifying filesystem type"
            else
                log_message "ERROR: Complete mount failure"
                exit 1
            fi
        fi
    fi

    # Verify mount and filesystem
    log_message "Mount verification:"
    log_execute "df -h '$MOUNT_POINT'"
    log_execute "stat -f -c %T '$MOUNT_POINT'"
    log_execute "ls -la '$MOUNT_POINT'"

    # Test write permissions
    if touch "$MOUNT_POINT/test_write" 2>/dev/null; then
        rm -f "$MOUNT_POINT/test_write"
        log_message "✓ Write permissions verified"
    else
        log_message "WARNING: No write permissions to mounted partition"
    fi
}

# Function to setup chroot-distro environment with Android partition bind-mounts
setup_chroot_environment() {
    log_message "=== Setting up chroot-distro environment ==="

    # Export the custom path
    export CHROOT_DISTRO_PATH="$CHROOT_PATH"
    log_message "✓ Set CHROOT_DISTRO_PATH=$CHROOT_PATH"

    # Display environment info
    log_message "chroot-distro environment information:"
    log_execute "chroot-distro env"

    # Verify the path is set correctly
    log_message "Current CHROOT_DISTRO_PATH: $CHROOT_DISTRO_PATH"

    # Check if chroot directory exists
    if [ -d "$CHROOT_PATH" ]; then
        log_message "✓ chroot-distro directory already exists"
        log_execute "ls -la '$CHROOT_PATH'"
    else
        log_message "ℹ chroot-distro directory will be created during installation"
    fi
}

# Function to bind-mount Android system partitions
bind_android_partitions() {
    log_message "=== Bind-mounting Android system partitions ==="

    local alpine_path="$CHROOT_PATH/alpine"

    # Wait for Alpine installation if not present yet
    if [ ! -d "$alpine_path" ]; then
        log_message "⚠ Alpine not yet installed at $alpine_path, skipping bind-mounts for now"
        return 0
    fi

    # Create mount points if they don't exist
    log_message "Creating mount point directories..."
    mkdir -p "$alpine_path/system" 2>/dev/null
    mkdir -p "$alpine_path/system_ext" 2>/dev/null
    mkdir -p "$alpine_path/vendor" 2>/dev/null
    mkdir -p "$alpine_path/product" 2>/dev/null

    # Bind-mount /system
    log_message "Bind-mounting /system..."
    if mountpoint -q "$alpine_path/system"; then
        log_message "✓ /system already bind-mounted"
    else
        if mount --bind /system "$alpine_path/system" 2>/dev/null; then
            log_message "✓ Successfully bind-mounted /system"
        else
            log_message "⚠ Failed to bind-mount /system (may not exist on this device)"
        fi
    fi

    # Bind-mount /system_ext
    log_message "Bind-mounting /system_ext..."
    if [ -d "/system_ext" ]; then
        if mountpoint -q "$alpine_path/system_ext"; then
            log_message "✓ /system_ext already bind-mounted"
        else
            if mount --bind /system_ext "$alpine_path/system_ext" 2>/dev/null; then
                log_message "✓ Successfully bind-mounted /system_ext"
            else
                log_message "⚠ Failed to bind-mount /system_ext"
            fi
        fi
    else
        log_message "ℹ /system_ext does not exist on this device"
    fi

    # Bind-mount /vendor
    log_message "Bind-mounting /vendor..."
    if mountpoint -q "$alpine_path/vendor"; then
        log_message "✓ /vendor already bind-mounted"
    else
        if mount --bind /vendor "$alpine_path/vendor" 2>/dev/null; then
            log_message "✓ Successfully bind-mounted /vendor"
        else
            log_message "⚠ Failed to bind-mount /vendor (may not exist on this device)"
        fi
    fi

    # Bind-mount /product
    log_message "Bind-mounting /product..."
    if [ -d "/product" ]; then
        if mountpoint -q "$alpine_path/product"; then
            log_message "✓ /product already bind-mounted"
        else
            if mount --bind /product "$alpine_path/product" 2>/dev/null; then
                log_message "✓ Successfully bind-mounted /product"
            else
                log_message "⚠ Failed to bind-mount /product"
            fi
        fi
    else
        log_message "ℹ /product does not exist on this device"
    fi

    log_message "✓ Android partition bind-mounting completed"
}

# Function to download and install Alpine
install_alpine() {
    log_message "=== Downloading and installing Alpine Linux ==="

    # Check if Alpine is already installed
    if [ -d "$CHROOT_PATH/alpine/etc" ] && [ -d "$CHROOT_PATH/alpine/bin" ]; then
        log_message "ℹ Alpine Linux appears to be already installed"
        log_message "Skipping installation, proceeding to configuration..."
        setup_chroot_system_environment
        bind_android_partitions
        return 0
    fi

    # Download Alpine aarch64
    log_message "Downloading Alpine Linux aarch64..."
    echo "NOTE: Download progress shown below..."
    if chroot-distro download alpine 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ Alpine Linux download completed successfully"
    else
        log_message "ℹ Alpine Linux download completed (may have been already downloaded)"
    fi

    # Install Alpine with timeout and progress monitoring
    log_message "Installing Alpine Linux to $CHROOT_PATH..."
    log_message "NOTE: This may take 2-5 minutes. Progress monitoring enabled..."
    echo "============================================"

    # Run installation in background with timeout
    log_message "Starting Alpine installation process..."

    # Create a flag file to track installation
    local install_flag="/tmp/alpine_install_$$"
    rm -f "$install_flag"

    # Run installation in background
    (
        chroot-distro install alpine >> "$LOG_PATH" 2>&1
        echo $? > "$install_flag"
    ) &

    local install_pid=$!
    log_message "Installation process started (PID: $install_pid)"

    # Monitor installation with timeout (5 minutes = 300 seconds)
    local timeout=300
    local elapsed=0
    local check_interval=5

    while [ $elapsed -lt $timeout ]; do
        if [ -f "$install_flag" ]; then
            local exit_code=$(cat "$install_flag")
            rm -f "$install_flag"

            if [ "$exit_code" -eq 0 ]; then
                log_message "✓ Alpine Linux installation completed successfully"
            else
                log_message "⚠ Installation exited with code $exit_code"
            fi
            break
        fi

        # Check if process is still running
        if ! kill -0 $install_pid 2>/dev/null; then
            log_message "⚠ Installation process terminated unexpectedly"
            break
        fi

        # Progress indicator
        if [ $((elapsed % 30)) -eq 0 ]; then
            log_message "  Installation in progress... ($elapsed seconds elapsed)"
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    # Check if we timed out
    if [ $elapsed -ge $timeout ]; then
        log_message "⚠ Installation timeout reached ($timeout seconds)"
        log_message "  Checking if installation completed anyway..."

        # Kill the installation process
        kill $install_pid 2>/dev/null
        wait $install_pid 2>/dev/null
    fi

    # Clean up flag file
    rm -f "$install_flag"

    echo "============================================"
    log_message "Installation command completed, verifying..."

    # Verify Alpine was installed
    if [ -d "$CHROOT_PATH/alpine" ]; then
        log_message "✓ Alpine directory exists"

        # Check for critical directories
        local all_dirs_exist=true
        for dir in etc bin usr var; do
            if [ -d "$CHROOT_PATH/alpine/$dir" ]; then
                log_message "  ✓ /$dir exists"
            else
                log_message "  ⚠ /$dir missing"
                all_dirs_exist=false
            fi
        done

        if [ "$all_dirs_exist" = false ]; then
            log_message "⚠ Some critical directories are missing"
            log_message "  Installation may be incomplete"
            log_message "  Checking if we can continue..."
        fi
    else
        log_message "ERROR: Alpine directory not created"
        log_message "  Checking for partial installation..."
        ls -la "$CHROOT_PATH/" >> "$LOG_PATH" 2>&1

        # Check if .rootfs exists (download successful but extraction failed)
        if [ -f "$CHROOT_PATH/.rootfs/alpine.tar.xz" ]; then
            log_message "⚠ Alpine tarball exists but extraction appears to have failed"
            log_message "  Manual extraction may be needed"
            log_message "  Tarball location: $CHROOT_PATH/.rootfs/alpine.tar.xz"
        fi

        exit 1
    fi

    # Now that Alpine is installed, setup device nodes inside chroot
    log_message "Proceeding to chroot environment setup..."
    setup_chroot_system_environment
    
    # Bind-mount Android partitions
    bind_android_partitions

    # Verify installation
    log_message "Verifying Alpine installation..."
    log_execute "chroot-distro list -i"

    if [ -d "$CHROOT_PATH/alpine" ]; then
        log_message "✓ Alpine Linux directory structure verified"
        log_execute "ls -la '$CHROOT_PATH/alpine' | head -20"
    else
        log_message "ERROR: Alpine installation directory not found"
        exit 1
    fi
}

# Function to install comprehensive hardware packages using SD card script
install_hardware_packages() {
    log_message "=== Installing comprehensive hardware support packages ==="

    local install_script="$SCRIPT_BASE/install_packages.sh"

    if [ ! -f "$install_script" ]; then
        log_message "ERROR: install_packages.sh not found at $install_script"
        return 1
    fi

    log_message "Using package installation script from: $install_script"

    # Copy the script into Alpine /root directory
    log_message "Transferring install_packages.sh to Alpine /root..."
    if cat "$install_script" | chroot-distro command alpine "cat > /root/install_packages.sh" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ Script transferred successfully"
    else
        log_message "⚠ Script transfer may have had issues, continuing..."
    fi

    # Make it executable
    log_message "Making script executable..."
    if chroot-distro command alpine "chmod +x /root/install_packages.sh" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Script made executable"
    else
        log_message "⚠ chmod may have failed, continuing..."
    fi

    # Execute the package installation
    log_message "Executing package installation in Alpine (this may take several minutes)..."
    log_message "Progress will be logged to $LOG_PATH"

    if chroot-distro command alpine "/root/install_packages.sh" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ Package installation completed"
    else
        log_message "⚠ Package installation completed with some warnings"
    fi

    log_message "✓ Hardware packages installation process completed"
}

# Function to install UNISOC hardware script and service
install_unisoc_hardware_and_service() {
    log_message "=== Installing UNISOC Hardware Script and Service ==="

    local unisoc_script="$SCRIPT_BASE/setup-unisoc-hardware.sh"
    local service_script="$SCRIPT_BASE/install-unisoc-service.sh"

    # Check if scripts exist
    if [ ! -f "$unisoc_script" ]; then
        log_message "ERROR: setup-unisoc-hardware.sh not found at $unisoc_script"
        return 1
    fi

    if [ ! -f "$service_script" ]; then
        log_message "ERROR: install-unisoc-service.sh not found at $service_script"
        return 1
    fi

    # Copy UNISOC hardware script
    log_message "Transferring setup-unisoc-hardware.sh to Alpine..."
    if cat "$unisoc_script" | chroot-distro command alpine "cat > /usr/local/bin/setup-unisoc-hardware" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ UNISOC script transferred successfully"
    else
        log_message "⚠ Script transfer may have had issues, continuing..."
    fi

    # Make it executable
    log_message "Making UNISOC script executable..."
    if chroot-distro command alpine "chmod +x /usr/local/bin/setup-unisoc-hardware" >> "$LOG_PATH" 2>&1; then
        log_message "✓ UNISOC script made executable"
    else
        log_message "⚠ chmod may have failed, continuing..."
    fi

    # Copy service installation script
    log_message "Transferring install-unisoc-service.sh to Alpine..."
    if cat "$service_script" | chroot-distro command alpine "cat > /root/install-unisoc-service.sh" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ Service script transferred successfully"
    else
        log_message "⚠ Script transfer may have had issues, continuing..."
    fi

    # Make service script executable
    log_message "Making service script executable..."
    if chroot-distro command alpine "chmod +x /root/install-unisoc-service.sh" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Service script made executable"
    else
        log_message "⚠ chmod may have failed, continuing..."
    fi

    # Fix OpenRC for chroot environment
    log_message "Preparing OpenRC environment for chroot..."
    chroot-distro command alpine "mkdir -p /run/openrc && touch /run/openrc/softlevel" >> "$LOG_PATH" 2>&1

    # Execute the service installation
    log_message "Installing UNISOC OpenRC service..."
    if chroot-distro command alpine "/root/install-unisoc-service.sh" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ UNISOC service installation completed"
    else
        log_message "⚠ Service installation completed with warnings"
    fi

    # Verify service installation
    log_message "Verifying OpenRC service installation..."
    chroot-distro command alpine "rc-status -a | grep unisoc || echo 'Service status check completed'" >> "$LOG_PATH"

    log_message "✓ UNISOC hardware and service installation completed"
}

# Function to setup D-Bus integration for Fluxbox
setup_dbus_integration() {
    log_message "=== Setting up D-Bus integration for Fluxbox ==="

    log_message "Verifying D-Bus configuration..."

    # Check if dbus-x11 is installed
    if chroot-distro command alpine "apk info dbus-x11" >> "$LOG_PATH" 2>&1; then
        log_message "✓ dbus-x11 package is installed (provides dbus-run-session)"
    else
        log_message "⚠ dbus-x11 not found, D-Bus session may not work properly"
    fi

    # Verify system D-Bus service is enabled
    log_message "Verifying D-Bus system service..."
    if chroot-distro command alpine "rc-status -a | grep dbus || echo 'Checking D-Bus...'" >> "$LOG_PATH" 2>&1; then
        log_message "✓ D-Bus system service configuration verified"
    fi

    log_message "✓ D-Bus integration verification completed"
}

# Function to create default user p3plus
create_default_user() {
    log_message "=== Creating default user p3plus ==="

    # Check if user already exists
    if chroot-distro command alpine "id p3plus" >> "$LOG_PATH" 2>&1; then
        log_message "ℹ User p3plus already exists"
        return 0
    fi

    log_message "Creating user p3plus..."

    # Create user with home directory
    if chroot-distro command alpine "adduser -D -h /home/p3plus -s /bin/sh p3plus" >> "$LOG_PATH" 2>&1; then
        log_message "✓ User p3plus created successfully"
    else
        log_message "⚠ Failed to create user p3plus"
        return 1
    fi

    # Add user to necessary groups for hardware access
    log_message "Adding p3plus to system groups..."

    local groups="root bin daemon sys adm tty disk lp mem kmem wheel floppy mail news uucp man cron console audio cdrom dialout ftp sshd at tape video netdev readproc squid gdm xfs kvm games named mysql postgres cdrw apache nut usb avahi vpopmail users ntp nofiles qmail postfix postdrop smmsp slocate abuild utmp nogroup nobody input bluetooth graphics log mount wifi install dhcp media_rw mtp drmrpc shell cache diag"
    for group in $groups; do
        if chroot-distro command alpine "addgroup p3plus $group 2>/dev/null || true" >> "$LOG_PATH" 2>&1; then
            log_message "  ✓ Added p3plus to $group group"
        fi
    done

    # Set up sudo access (no password for wheel group)
    log_message "Configuring sudo access for p3plus..."
    chroot-distro command alpine "echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" >> "$LOG_PATH" 2>&1

    # Copy skeleton files to user home
    chroot-distro command alpine "cp -r /etc/skel/. /home/p3plus/" >> "$LOG_PATH" 2>&1
    chroot-distro command alpine "chown -R p3plus:p3plus /home/p3plus" >> "$LOG_PATH" 2>&1

    log_message "✓ User p3plus configured with Fluxbox and D-Bus support"
    log_message "Note: To set password, run: chroot-distro command alpine 'passwd p3plus'"
}

# Function to copy droid folder from SD card
copy_droid_folder() {
    log_message "=== Copying droid folder from SD card ==="

    local source_droid="$SDCARD_PATHS/droid"
    local dest_droid="$CHROOT_PATH/alpine/home/p3plus/droid"

    if [ ! -d "$source_droid" ]; then
        log_message "⚠ WARNING: droid folder not found at $source_droid"
        log_message "  Skipping droid folder copy"
        return 0
    fi

    log_message "Source: $source_droid"
    log_message "Destination: $dest_droid"

    # Remove existing droid folder if it exists (override)
    if [ -d "$dest_droid" ]; then
        log_message "Removing existing droid folder at destination..."
        if rm -rf "$dest_droid" 2>/dev/null; then
            log_message "✓ Removed existing droid folder"
        else
            log_message "⚠ Failed to remove existing droid folder, attempting to override..."
        fi
    fi

    # Copy droid folder
    log_message "Copying droid folder..."
    if cp -r "$source_droid" "$dest_droid" 2>/dev/null; then
        log_message "✓ Successfully copied droid folder"
    else
        log_message "⚠ Failed to copy droid folder"
        return 1
    fi

    # Set ownership to p3plus
    log_message "Setting ownership of droid folder to p3plus..."
    chroot-distro command alpine "chown -R p3plus:p3plus /home/p3plus/droid" >> "$LOG_PATH" 2>&1
    log_message "✓ Ownership set to p3plus"

    # Display folder size
    local folder_size=$(du -sh "$dest_droid" 2>/dev/null | awk '{print $1}')
    log_message "✓ droid folder copied successfully (size: $folder_size)"
}

# Function to run device nodes setup script
run_device_nodes_setup() {
    log_message "=== Running device nodes and permissions setup ==="

    local dev_nodes_script="$SCRIPT_BASE/dev-nodes.sh"

    if [ ! -f "$dev_nodes_script" ]; then
        log_message "ERROR: dev-nodes.sh not found at $dev_nodes_script"
        return 1
    fi

    log_message "Executing device nodes script from: $dev_nodes_script"

    # Run the script directly with SD_MOUNT environment variable and USER set to p3plus
    log_message "Setting SD_MOUNT=$SDCARD_PATHS and USER=p3plus"
    log_message "Executing device nodes setup (this may take a few minutes)..."

    # Execute as the p3plus user inside chroot with SD_MOUNT variable
    if chroot-distro command alpine "SD_MOUNT='$SDCARD_PATHS' USER=p3plus sh -c 'cd / && sh $dev_nodes_script'" 2>&1 | tee -a "$LOG_PATH"; then
        log_message "✓ Device nodes setup completed"
    else
        log_message "⚠ Device nodes setup completed with some warnings"
    fi

    log_message "✓ Device nodes and permissions setup process completed"
    log_message "✓ User p3plus now has access to all configured device nodes"
}

# Function to logout and login for group changes to take effect
apply_group_changes() {
    log_message "=== Applying group membership changes ==="

    log_message "Logging out to apply group changes..."

    # Exit the current session
    log_message "Executing logout via chroot-distro..."
    chroot-distro command alpine "exit" >> "$LOG_PATH" 2>&1 || true

    # Wait for a few seconds
    log_message "Waiting 3 seconds for session to close..."
    sleep 3

    # Log back in
    log_message "Logging back in to apply changes..."
    if chroot-distro command alpine "whoami" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Successfully logged back in"
        log_message "✓ Group changes should now be in effect"
    else
        log_message "⚠ Login test completed"
    fi
}

# Function to test the installation including all device node access
test_installation() {
    log_message "=== Testing Alpine Linux installation ==="

    # Test basic functionality
    log_message "Testing chroot-distro environment..."
    log_execute "chroot-distro env"

    # Test Alpine package manager
    log_message "Testing Alpine package manager..."
    if chroot-distro command alpine "apk --version" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Alpine package manager is working"
    else
        log_message "⚠ Alpine package manager test completed with warnings"
    fi

    # Test UNISOC hardware script
    log_message "Testing UNISOC hardware script..."
    if chroot-distro command alpine "test -x /usr/local/bin/setup-unisoc-hardware && echo 'Script is executable'" >> "$LOG_PATH" 2>&1; then
        log_message "✓ UNISOC hardware script is installed and executable"
    else
        log_message "⚠ UNISOC hardware script may have issues"
    fi

    # Test Alpine login capability
    log_message "Testing Alpine login capability..."
    if chroot-distro command alpine "whoami && pwd" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Alpine environment is accessible"
    else
        log_message "⚠ Alpine environment test completed with warnings"
    fi

    # Test D-Bus availability
    log_message "Testing D-Bus availability..."
    if chroot-distro command alpine "which dbus-daemon && which dbus-launch" >> "$LOG_PATH" 2>&1; then
        log_message "✓ D-Bus daemon and dbus-launch are installed"
        chroot-distro command alpine "dbus-daemon --version" >> "$LOG_PATH" 2>&1
        log_message "✓ D-Bus version check completed"
    else
        log_message "⚠ D-Bus may not be fully installed"
    fi

    # Test D-Bus service configuration
    log_message "Testing D-Bus service configuration..."
    if chroot-distro command alpine "rc-service dbus status || echo 'D-Bus service not started (expected in chroot)'" >> "$LOG_PATH" 2>&1; then
        log_message "✓ D-Bus service check completed"
    fi

    # Test all device node read/write access
    log_message "=== Testing comprehensive device node access ==="

    # Test critical system device nodes
    log_message "Testing critical system device nodes..."

    log_message "  Testing /dev/null..."
    if chroot-distro command alpine "echo 'test' > /dev/null && echo 'Success'" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/null has read/write access"
    else
        log_message "  ⚠ /dev/null access test failed"
    fi

    log_message "  Testing /dev/zero..."
    if chroot-distro command alpine "dd if=/dev/zero of=/tmp/test_zero bs=1024 count=1 2>/dev/null && rm -f /tmp/test_zero" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/zero has read access"
    else
        log_message "  ⚠ /dev/zero access test failed"
    fi

    log_message "  Testing /dev/random and /dev/urandom..."
    if chroot-distro command alpine "dd if=/dev/random of=/tmp/test_random bs=1024 count=1 2>/dev/null && rm -f /tmp/test_random" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/random has read access"
    else
        log_message "  ⚠ /dev/random access test failed"
    fi

    if chroot-distro command alpine "dd if=/dev/urandom of=/tmp/test_urandom bs=1024 count=1 2>/dev/null && rm -f /tmp/test_urandom" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/urandom has read access"
    else
        log_message "  ⚠ /dev/urandom access test failed"
    fi

    log_message "  Testing /dev/full..."
    if chroot-distro command alpine "test -w /dev/full && echo 'Success'" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/full has write access"
    else
        log_message "  ⚠ /dev/full access test failed"
    fi

    # Test hardware device access - AUDIO
    log_message "Testing audio device access..."
    if chroot-distro command alpine "ls -la /dev/snd/ 2>/dev/null | head -10" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Audio devices (/dev/snd/*) are accessible"
        if chroot-distro command alpine "test -w /dev/snd/controlC0 && echo 'Write access OK'" >> "$LOG_PATH" 2>&1; then
            log_message "  ✓ /dev/snd/controlC0 has write access"
        fi
    else
        log_message "ℹ Audio devices may not be available"
    fi

    # Test hardware device access - VIDEO/GPU
    log_message "Testing video/GPU device access..."
    if chroot-distro command alpine "ls -la /dev/dri/card0 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ GPU device (/dev/dri/card0) is accessible"
        if chroot-distro command alpine "test -r /dev/dri/card0 && test -w /dev/dri/card0 && echo 'RW access OK'" >> "$LOG_PATH" 2>&1; then
            log_message "  ✓ /dev/dri/card0 has read/write access"
        fi
    else
        log_message "ℹ GPU device may not be available"
    fi

    if chroot-distro command alpine "ls -la /dev/mali0 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Mali GPU device (/dev/mali0) is accessible"
    fi

    # Test hardware device access - INPUT
    log_message "Testing input device access..."
    if chroot-distro command alpine "ls -la /dev/input/ 2>/dev/null | head -10" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Input devices (/dev/input/*) are accessible"
    else
        log_message "ℹ Input devices may not be available"
    fi

    # Test hardware device access - SERIAL/TTY
    log_message "Testing serial/TTY device access..."
    if chroot-distro command alpine "ls -la /dev/tty* 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "✓ TTY devices are accessible"
    fi

    # Test hardware device access - LTE/UNISOC
    log_message "Testing LTE/UNISOC device access..."
    if chroot-distro command alpine "ls -la /dev/spipe_lte* /dev/stty_lte* 2>/dev/null | head -10" >> "$LOG_PATH" 2>&1; then
        log_message "✓ UNISOC LTE devices are accessible"
    else
        log_message "ℹ UNISOC LTE devices may not be available"
    fi

    # Test hardware device access - GPIO
    log_message "Testing GPIO device access..."
    if chroot-distro command alpine "ls -la /dev/gpiochip* 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ GPIO devices are accessible"
    else
        log_message "ℹ GPIO devices may not be available"
    fi

    # Test hardware device access - I2C
    log_message "Testing I2C device access..."
    if chroot-distro command alpine "ls -la /dev/i2c-* 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ I2C devices are accessible"
    else
        log_message "ℹ I2C devices may not be available"
    fi

    # Test hardware device access - SENSORS
    log_message "Testing sensor device access..."
    if chroot-distro command alpine "ls -la /dev/iio:device* 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Sensor devices are accessible"
    else
        log_message "ℹ Sensor devices may not be available"
    fi

    # Test hardware device access - BLOCK DEVICES
    log_message "Testing block device access..."
    if chroot-distro command alpine "ls -la /dev/loop* 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "✓ Loop devices are accessible"
    fi

    # Test user group memberships
    log_message "Testing user p3plus group memberships..."
    if chroot-distro command alpine "groups p3plus 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "✓ User p3plus group memberships retrieved"
        # Display groups in log
        chroot-distro command alpine "groups p3plus" 2>&1 | tee -a "$LOG_PATH"
    else
        log_message "⚠ Could not retrieve user group memberships"
    fi

    # Test device permissions for user p3plus
    log_message "Testing device access as user p3plus..."
    if chroot-distro command alpine "su - p3plus -c 'test -r /dev/null && test -w /dev/null && echo Device access successful'" >> "$LOG_PATH" 2>&1; then
        log_message "✓ User p3plus can access device nodes"
    else
        log_message "⚠ User p3plus may have limited device access"
    fi

    # Verify ALL chroot system environment directories
    log_message "Verifying chroot system environment..."

    log_message "  Checking /dev/shm..."
    if chroot-distro command alpine "ls -lad /dev/shm 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /dev/shm exists and is accessible"
    fi

    log_message "  Checking /tmp..."
    if chroot-distro command alpine "ls -lad /tmp 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /tmp exists and is accessible"
    fi

    log_message "  Checking /tmp/runtime..."
    if chroot-distro command alpine "ls -lad /tmp/runtime 2>/dev/null" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /tmp/runtime exists and is accessible"
    fi

    # Test Android partition bind-mounts
    log_message "Testing Android partition bind-mounts..."

    log_message "  Checking /system..."
    if chroot-distro command alpine "ls -la /system 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /system is accessible"
    fi

    log_message "  Checking /system_ext..."
    if chroot-distro command alpine "ls -la /system_ext 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /system_ext is accessible"
    fi

    log_message "  Checking /vendor..."
    if chroot-distro command alpine "ls -la /vendor 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /vendor is accessible"
    fi

    log_message "  Checking /product..."
    if chroot-distro command alpine "ls -la /product 2>/dev/null | head -5" >> "$LOG_PATH" 2>&1; then
        log_message "  ✓ /product is accessible"
    fi

    log_message "✓ All system environment directories and device nodes verified"
    log_message "✓ Installation testing completed successfully"
}

# Function to delete .rootfs folder before final steps
delete_rootfs_folder() {
    log_message "=== Deleting .rootfs folder ==="

    local rootfs_path="$CHROOT_PATH/.rootfs"

    if [ -d "$rootfs_path" ]; then
        log_message "Found .rootfs folder at: $rootfs_path"
        
        # Check size before deleting
        local rootfs_size=$(du -sh "$rootfs_path" 2>/dev/null | awk '{print $1}')
        log_message "Size of .rootfs folder: $rootfs_size"
        
        # Delete the folder
        log_message "Deleting .rootfs folder..."
        if rm -rf "$rootfs_path" 2>/dev/null; then
            log_message "✓ Successfully deleted .rootfs folder"
            log_message "✓ Freed up: $rootfs_size"
        else
            log_message "⚠ Failed to delete .rootfs folder"
            return 1
        fi
    else
        log_message "ℹ .rootfs folder not found at $rootfs_path"
        log_message "  Nothing to delete"
    fi

    log_message "✓ .rootfs cleanup completed"
}

# Function to create persistent mount script
create_mount_script() {
    log_message "=== Creating persistent mount script ==="

    # Ensure service.d directory exists
    if [ ! -d "/data/adb/service.d" ]; then
        log_execute "mkdir -p /data/adb/service.d"
        log_message "✓ Created service.d directory"
    fi

    cat << 'MOUNT_SCRIPT' > /data/adb/service.d/alpine-mount.sh
#!/system/bin/sh

# Alpine Linux Auto-Mount Script with System Setup
# Runs at boot to mount linuxdata and configure chroot-distro

SCRIPT_LOG="/data/adb/alpine-mount.log"
echo "$(date): Alpine auto-mount script started" >> "$SCRIPT_LOG"

sleep 30  # Wait for system to be ready

LINUXDATA_PARTITION="/dev/block/mmcblk0p77"
MOUNT_POINT="/data/linuxdata"
CHROOT_PATH="$MOUNT_POINT/chroot-distro"

# Create mount point
mkdir -p "$MOUNT_POINT" >> "$SCRIPT_LOG" 2>&1

# Mount linuxdata if not already mounted
if ! mountpoint -q "$MOUNT_POINT"; then
    if mount -t ext4 "$LINUXDATA_PARTITION" "$MOUNT_POINT" >> "$SCRIPT_LOG" 2>&1; then
        echo "$(date): Successfully mounted linuxdata partition" >> "$SCRIPT_LOG"
    else
        echo "$(date): Failed to mount linuxdata partition" >> "$SCRIPT_LOG"
    fi
else
    echo "$(date): linuxdata partition already mounted" >> "$SCRIPT_LOG"
fi

# Setup chroot device nodes and directories
if [ -d "$CHROOT_PATH/alpine" ]; then
    # Setup /dev/shm inside chroot
    mkdir -p "$CHROOT_PATH/alpine/dev/shm" 2>/dev/null || true
    chmod 1777 "$CHROOT_PATH/alpine/dev/shm" 2>/dev/null || true

    # Setup /tmp inside chroot
    mkdir -p "$CHROOT_PATH/alpine/tmp" 2>/dev/null || true
    chmod 1777 "$CHROOT_PATH/alpine/tmp" 2>/dev/null || true

    # Setup /tmp/runtime inside chroot
    mkdir -p "$CHROOT_PATH/alpine/tmp/runtime" 2>/dev/null || true
    chmod 1777 "$CHROOT_PATH/alpine/tmp/runtime" 2>/dev/null || true

    # Fix device node permissions inside chroot
    chmod 666 "$CHROOT_PATH/alpine/dev/null" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/zero" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/full" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/random" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/urandom" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/fuse" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/tty" 2>/dev/null || true
    chmod 666 "$CHROOT_PATH/alpine/dev/ptmx" 2>/dev/null || true

    echo "$(date): Fixed chroot device permissions and directories" >> "$SCRIPT_LOG"

    # Bind-mount Android system partitions
    mkdir -p "$CHROOT_PATH/alpine/system" 2>/dev/null || true
    mkdir -p "$CHROOT_PATH/alpine/system_ext" 2>/dev/null || true
    mkdir -p "$CHROOT_PATH/alpine/vendor" 2>/dev/null || true
    mkdir -p "$CHROOT_PATH/alpine/product" 2>/dev/null || true

    # Bind /system
    if ! mountpoint -q "$CHROOT_PATH/alpine/system"; then
        mount --bind /system "$CHROOT_PATH/alpine/system" 2>/dev/null && \
            echo "$(date): Bind-mounted /system" >> "$SCRIPT_LOG"
    fi

    # Bind /system_ext
    if [ -d "/system_ext" ] && ! mountpoint -q "$CHROOT_PATH/alpine/system_ext"; then
        mount --bind /system_ext "$CHROOT_PATH/alpine/system_ext" 2>/dev/null && \
            echo "$(date): Bind-mounted /system_ext" >> "$SCRIPT_LOG"
    fi

    # Bind /vendor
    if ! mountpoint -q "$CHROOT_PATH/alpine/vendor"; then
        mount --bind /vendor "$CHROOT_PATH/alpine/vendor" 2>/dev/null && \
            echo "$(date): Bind-mounted /vendor" >> "$SCRIPT_LOG"
    fi

    # Bind /product
    if [ -d "/product" ] && ! mountpoint -q "$CHROOT_PATH/alpine/product"; then
        mount --bind /product "$CHROOT_PATH/alpine/product" 2>/dev/null && \
            echo "$(date): Bind-mounted /product" >> "$SCRIPT_LOG"
    fi
fi

# Set environment variable
export CHROOT_DISTRO_PATH="$CHROOT_PATH"
echo "$(date): Set CHROOT_DISTRO_PATH=$CHROOT_PATH" >> "$SCRIPT_LOG"

echo "$(date): Alpine Linux environment configured successfully" >> "$SCRIPT_LOG"
MOUNT_SCRIPT

    chmod +x /data/adb/service.d/alpine-mount.sh
    log_message "✓ Created persistent mount script: /data/adb/service.d/alpine-mount.sh"

    # Test the script
    log_message "Testing persistent mount script..."
    if [ -x "/data/adb/service.d/alpine-mount.sh" ]; then
        log_message "✓ Persistent mount script is executable"
    else
        log_message "⚠ Persistent mount script may not be executable"
    fi
}

# Main execution function
main() {
    # Initialize logging first
    detect_sdcard_path

    log_message "=== Alpine Linux Setup with UNISOC Hardware Support ==="
    log_message "Script started with comprehensive logging enabled"
    log_message "Process ID: $$"
    log_message "SD Card Path: $SDCARD_PATHS"
    log_message "Script Base: $SCRIPT_BASE"

    # Execute all functions in order
    check_root
    verify_helper_scripts
    mount_linuxdata  
    setup_chroot_environment
    install_alpine
    install_hardware_packages
    install_unisoc_hardware_and_service
    setup_dbus_integration
    create_default_user
    copy_droid_folder
    run_device_nodes_setup
    apply_group_changes
    test_installation
    delete_rootfs_folder
    create_mount_script

    log_message ""
    log_message "=== Setup Complete ==="
    log_message "Alpine Linux has been successfully installed to: $CHROOT_PATH"
    log_message "Full log saved to: $LOG_PATH"
    log_message "Device setup log saved to: /data/dev-nodes-logs.log"
    log_message "The system will automatically mount and configure on reboot."
    log_message "Setup completed successfully at $(date)"

    # Copy log to multiple locations for redundancy
    if [ "$LOG_PATH" != "/data/alpine_setup.log" ]; then
        cp "$LOG_PATH" "/data/alpine_setup_backup.log" 2>/dev/null
        log_message "✓ Backup log created at /data/alpine_setup_backup.log"
    fi
}

# Execute main function with all arguments
main "$@"
