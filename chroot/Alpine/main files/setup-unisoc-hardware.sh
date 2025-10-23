#!/bin/sh
# UNISOC Hardware Device Configuration Script
# Configures permissions for all UNISOC-specific and standard devices

HARDWARE_LOG="/data/unisoc_hardware.log"
echo "=== UNISOC Hardware Configuration Started at $(date) ===" > "$HARDWARE_LOG"

hw_log() {
    echo "$(date '+%H:%M:%S') - $1" | tee -a "$HARDWARE_LOG"
}

configure_device() {
    local device="$1"
    if [ -e "$device" ]; then
        if chmod 666 "$device" 2>/dev/null; then
            hw_log "  ✓ Configured: $device"
            return 0
        else
            hw_log "  ⚠ Failed: $device (permission denied)"
            return 1
        fi
    fi
    return 2
}

configure_device_group() {
    local pattern="$1"
    local description="$2"
    local count=0

    hw_log "Configuring $description..."
    for device in $pattern; do
        if configure_device "$device"; then
            count=$((count + 1))
        fi
    done
    hw_log "  Total configured: $count"
    return $count
}

# === NEW: V4L2 CAMERA INITIALIZATION FUNCTION ===
initialize_v4l2_cameras() {
    hw_log "=== Initializing V4L2 Camera System ==="
    
    # Check if camera modules are loaded
    if ! lsmod | grep -q sprd_sensor; then
        hw_log "  ⚠ sprd_sensor module not loaded, attempting to load..."
        modprobe sprd_sensor 2>/dev/null || insmod /vendor/lib/modules/sprd_sensor.ko 2>/dev/null
        sleep 1
    fi
    
    if ! lsmod | grep -q sprd_cpp; then
        hw_log "  ⚠ sprd_cpp module not loaded, attempting to load..."
        modprobe sprd_cpp 2>/dev/null || insmod /vendor/lib/modules/sprd_cpp.ko 2>/dev/null
        sleep 1
    fi
    
    # Check for camera platform device
    if [ -d /sys/devices/platform/soc/soc:cam-subsys ] || \
       [ -d /sys/devices/platform/camera ] || \
       [ -d /sys/devices/virtual/video4linux ]; then
        hw_log "  ✓ Camera platform device detected"
    else
        hw_log "  ⚠ Camera platform device not found"
    fi
    
    # Trigger V4L2 device creation by writing to sysfs
    hw_log "  Triggering V4L2 device enumeration..."
    
    # Method 1: Trigger camera sensor probe
    if [ -f /sys/devices/platform/soc/soc:cam-subsys/driver/probe ]; then
        echo "soc:cam-subsys" > /sys/devices/platform/soc/soc:cam-subsys/driver/probe 2>/dev/null
        hw_log "    Triggered camera subsystem probe"
    fi
    
    # Method 2: Manually create video devices if they don't exist
    if [ ! -e /dev/video0 ]; then
        hw_log "  Creating V4L2 video device nodes..."
        
        # Create video devices (typically 0-15 for SPRD camera system)
        for i in $(seq 0 15); do
            # Video device major number is 81
            if [ ! -e /dev/video$i ]; then
                mknod /dev/video$i c 81 $i 2>/dev/null
                chmod 666 /dev/video$i 2>/dev/null
                hw_log "    Created: /dev/video$i"
            fi
        done
    fi
    
    # Create media devices
    if [ ! -e /dev/media0 ]; then
        hw_log "  Creating media controller devices..."
        for i in $(seq 0 3); do
            # Media device major number is 250
            if [ ! -e /dev/media$i ]; then
                mknod /dev/media$i c 250 $i 2>/dev/null
                chmod 666 /dev/media$i 2>/dev/null
                hw_log "    Created: /dev/media$i"
            fi
        done
    fi
    
    # Create v4l-subdev devices
    if [ ! -e /dev/v4l-subdev0 ]; then
        hw_log "  Creating V4L2 subdev nodes..."
        for i in $(seq 0 7); do
            # V4L subdev major number is 81, minor starts at 128
            minor=$((128 + i))
            if [ ! -e /dev/v4l-subdev$i ]; then
                mknod /dev/v4l-subdev$i c 81 $minor 2>/dev/null
                chmod 666 /dev/v4l-subdev$i 2>/dev/null
                hw_log "    Created: /dev/v4l-subdev$i"
            fi
        done
    fi
    
    # Wait for devices to settle
    sleep 2
    
    # Verify V4L2 devices were created
    VIDEO_COUNT=$(ls /dev/video* 2>/dev/null | wc -l)
    MEDIA_COUNT=$(ls /dev/media* 2>/dev/null | wc -l)
    SUBDEV_COUNT=$(ls /dev/v4l-subdev* 2>/dev/null | wc -l)
    
    hw_log "  V4L2 Initialization Summary:"
    hw_log "    Video devices: $VIDEO_COUNT"
    hw_log "    Media devices: $MEDIA_COUNT"
    hw_log "    Subdev devices: $SUBDEV_COUNT"
    
    if [ $VIDEO_COUNT -gt 0 ] || [ $MEDIA_COUNT -gt 0 ]; then
        hw_log "  ✓ V4L2 camera system initialized successfully"
        return 0
    else
        hw_log "  ⚠ V4L2 camera initialization incomplete"
        return 1
    fi
}

# === NEW: CAMERA GPIO INITIALIZATION ===
initialize_camera_gpio() {
    hw_log "=== Initializing Camera GPIOs ==="
    
    # Export common camera GPIOs (adjust numbers based on your device tree)
    # These are typical SPRD camera GPIO pins
    CAMERA_GPIOS="119 120 121 122 123 124 125 126"
    
    for gpio in $CAMERA_GPIOS; do
        if [ ! -d /sys/class/gpio/gpio$gpio ]; then
            echo $gpio > /sys/class/gpio/export 2>/dev/null
            if [ $? -eq 0 ]; then
                hw_log "  ✓ Exported GPIO $gpio"
                # Set as output
                echo out > /sys/class/gpio/gpio$gpio/direction 2>/dev/null
                # Set initial value (optional)
                echo 0 > /sys/class/gpio/gpio$gpio/value 2>/dev/null
            fi
        fi
    done
    
    hw_log "  Camera GPIO initialization complete"
}

# === NEW: DCAM (Digital Camera) INITIALIZATION ===
initialize_dcam() {
    hw_log "=== Initializing DCAM (Digital Camera Controller) ==="
    
    # Check for DCAM device in sysfs
    DCAM_PATHS="/sys/devices/platform/soc/soc:cam-subsys/dcam* \
                /sys/devices/platform/dcam* \
                /sys/module/sprd_sensor/parameters"
    
    for path in $DCAM_PATHS; do
        if [ -e "$path" ]; then
            hw_log "  ✓ Found DCAM path: $path"
        fi
    done
    
    # Enable DCAM if control file exists
    if [ -f /sys/devices/platform/soc/soc:cam-subsys/dcam_enable ]; then
        echo 1 > /sys/devices/platform/soc/soc:cam-subsys/dcam_enable 2>/dev/null
        hw_log "  ✓ Enabled DCAM controller"
    fi
    
    # Set DCAM parameters if available
    if [ -d /sys/module/sprd_sensor/parameters ]; then
        hw_log "  ✓ DCAM parameters accessible"
    fi
}

hw_log "=== Starting Hardware Device Configuration ==="

# UNISOC LTE Pipe Devices (15 devices: spipe_lte0-14)
configure_device_group "/dev/spipe_lte*" "UNISOC LTE Pipe Devices"

# UNISOC LTE TTY Devices (32 devices: stty_lte0-31)
configure_device_group "/dev/stty_lte*" "UNISOC LTE TTY Devices"

# UNISOC Log Devices (5 devices)
configure_device_group "/dev/slog_*" "UNISOC Log Devices"

# UNISOC Diagnostic Devices
configure_device "/dev/sdiag_lte"

# UNISOC Power Management Devices
configure_device_group "/dev/spipe_pm*" "UNISOC Power Management Pipes"
configure_device "/dev/sctl_pm"

# TTY Gadget Serial Devices (8 devices: ttyGS0-7)
hw_log "Configuring TTY Gadget Serial Devices..."
tty_count=0
for i in $(seq 0 7); do
    if configure_device "/dev/ttyGS$i"; then
        tty_count=$((tty_count + 1))
    fi
done
hw_log "  Total TTY gadget devices configured: $tty_count"

# Standard Serial Devices (2 devices: ttyS0-1)
hw_log "Configuring Standard Serial Devices..."
for i in 0 1; do
    configure_device "/dev/ttyS$i"
done

# GPIO Controller Devices (6 devices: gpiochip0-5)
hw_log "Configuring GPIO Controller Devices..."
gpio_count=0
for i in $(seq 0 5); do
    if configure_device "/dev/gpiochip$i"; then
        gpio_count=$((gpio_count + 1))
    fi
done
hw_log "  Total GPIO devices configured: $gpio_count"

# I2C Bus Devices (6 devices: i2c-0 to i2c-5)
hw_log "Configuring I2C Bus Devices..."
i2c_count=0
for i in $(seq 0 5); do
    if configure_device "/dev/i2c-$i"; then
        i2c_count=$((i2c_count + 1))
    fi
done
hw_log "  Total I2C devices configured: $i2c_count"

# IIO Sensor Devices (2 devices)
hw_log "Configuring IIO Sensor Devices..."
for i in 0 1; do
    configure_device "/dev/iio:device$i"
done

# Input Event Devices (event devices, joystick, and mice)
hw_log "Configuring Input Devices..."
input_count=0
for device in /dev/input/event* /dev/input/js* /dev/input/mice; do
    if configure_device "$device"; then
        input_count=$((input_count + 1))
    fi
done
hw_log "  Total input devices configured: $input_count"

# ALSA Audio Devices (31 devices in /dev/snd/)
hw_log "Configuring ALSA Audio Devices..."
audio_count=0
for device in /dev/snd/*; do
    if configure_device "$device"; then
        audio_count=$((audio_count + 1))
    fi
done
hw_log "  Total audio devices configured: $audio_count"

# DRM Graphics Device
hw_log "Configuring Graphics Devices..."
configure_device "/dev/dri/card0"

# USB Devices
hw_log "Configuring USB Devices..."
usb_count=0
for device in /dev/bus/usb/*/*; do
    if configure_device "$device"; then
        usb_count=$((usb_count + 1))
    fi
done
hw_log "  Total USB devices configured: $usb_count"

# RTC Device
configure_device "/dev/rtc0"

# Wireless/Cellular Devices
hw_log "Configuring Wireless/Cellular Devices..."
configure_device "/dev/wcn"
configure_device "/dev/wcn_op"

# GNSS Devices (4 devices)
hw_log "Configuring GNSS Devices..."
configure_device "/dev/gnss_dbg"
configure_device "/dev/gnss_common_ctl"
configure_device "/dev/gnss_pmnotify_ctl"
configure_device "/dev/data0_gnss"

# Audio Pipe Devices
hw_log "Configuring Audio Pipe Devices..."
configure_device_group "/dev/audio_pipe_*" "Audio Pipe Devices"

# UNISOC/Spreadtrum Specific Devices
hw_log "Configuring Spreadtrum/UNISOC Specific Devices..."
configure_device "/dev/sprd_vsp"      # Video processing
configure_device "/dev/sprd_jpg"      # JPEG hardware
configure_device "/dev/sprd_uid"      # Unique ID
configure_device "/dev/sprd_cpp"      # CPP processor
configure_device "/dev/sprd_flash"    # Flash controller
configure_device "/dev/sprd_sensor"   # Sensor controller
configure_device "/dev/gsp"           # Graphics Signal Processor
configure_device "/dev/cptl"          # Control protocol
configure_device "/dev/mali0"         # Mali GPU direct access
configure_device "/dev/vdsp0"         # Video DSP

# === NEW: INITIALIZE CAMERA SYSTEM ===
initialize_camera_gpio
initialize_dcam
initialize_v4l2_cameras

# Configure V4L2 devices after creation
hw_log "Configuring V4L2 Camera Devices..."
v4l2_count=0
for device in /dev/video* /dev/media* /dev/v4l-subdev*; do
    if configure_device "$device"; then
        v4l2_count=$((v4l2_count + 1))
    fi
done
hw_log "  Total V4L2 devices configured: $v4l2_count"

# Bluetooth TTY Devices
hw_log "Configuring Bluetooth Devices..."
configure_device "/dev/ttyBT0"
configure_device "/dev/ttyBT1"

# Audio Pipe Command Devices
hw_log "Configuring Audio Pipe Command Devices..."
configure_device "/dev/apipe-cmd-in"
configure_device "/dev/apipe-cmd-out"
configure_device "/dev/apipe-pcm"

# RS Communication Devices
hw_log "Configuring RS Communication Devices..."
configure_device "/dev/rscom"
configure_device "/dev/rsinput"
configure_device "/dev/rstouch"

# Special Function Devices
hw_log "Configuring Special Function Devices..."
configure_device "/dev/fm"                  # FM radio
configure_device "/dev/autotest0"           # Autotest interface
configure_device "/dev/retrostation_hdmi"   # HDMI interface
configure_device "/dev/map_user"            # Memory mapper

# Network Devices
configure_device "/dev/ppp"
configure_device "/dev/tun"

# Additional System Devices
hw_log "Configuring Additional System Devices..."
configure_device "/dev/uhid"
configure_device "/dev/uinput"
configure_device "/dev/rfkill"
configure_device "/dev/fuse"
configure_device "/dev/ion"
configure_device "/dev/ashmem"

hw_log "=== Hardware Configuration Completed at $(date) ==="

# Generate summary
echo ""
echo "=========================================="
echo "UNISOC Hardware Configuration Summary"
echo "=========================================="
hw_log "UNISOC LTE devices: $(ls /dev/spipe_lte* /dev/stty_lte* 2>/dev/null | wc -l)"
hw_log "Serial devices: $(ls /dev/ttyGS* /dev/ttyS* 2>/dev/null | wc -l)"
hw_log "GPIO devices: $(ls /dev/gpiochip* 2>/dev/null | wc -l)"
hw_log "I2C devices: $(ls /dev/i2c-* 2>/dev/null | wc -l)"
hw_log "Audio devices: $(ls /dev/snd/* 2>/dev/null | wc -l)"
hw_log "Input devices: $(ls /dev/input/* 2>/dev/null | wc -l)"
hw_log "V4L2 video devices: $(ls /dev/video* 2>/dev/null | wc -l)"
hw_log "V4L2 media devices: $(ls /dev/media* 2>/dev/null | wc -l)"
hw_log "V4L2 subdev devices: $(ls /dev/v4l-subdev* 2>/dev/null | wc -l)"
echo ""
echo "Full log: $HARDWARE_LOG"
echo "=========================================="
