#!/bin/sh
# Alpine Linux Hardware Support Package Installation Script
# Tailored for UNISOC device with Panfrost GPU and Fluxbox window manager
# Optimized for ARM Mali GPU with comprehensive hardware support

LOG_FILE="/data/package_install.log"
echo "=== Alpine Package Installation Started at $(date) ===" > "$LOG_FILE"

# Function to log messages
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to install packages with error handling
install_pkg() {
    local pkg="$1"
    log_msg "Installing: $pkg"
    if apk add "$pkg" >> "$LOG_FILE" 2>&1; then
        log_msg "  ✓ SUCCESS: $pkg"
        return 0
    else
        log_msg "  ⚠ FAILED/SKIPPED: $pkg"
        return 1
    fi
}

# Function to install from edge repository
install_edge_pkg() {
    local pkg="$1"
    log_msg "Installing from edge: $pkg"
    if apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main "$pkg" >> "$LOG_FILE" 2>&1; then
        log_msg "  ✓ SUCCESS: $pkg (edge)"
        return 0
    else
        log_msg "  ⚠ FAILED/SKIPPED: $pkg (edge)"
        return 1
    fi
}

# Function to install from testing repository
install_testing_pkg() {
    local pkg="$1"
    log_msg "Installing from testing: $pkg"
    if apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing "$pkg" >> "$LOG_FILE" 2>&1; then
        log_msg "  ✓ SUCCESS: $pkg (testing)"
        return 0
    else
        log_msg "  ⚠ FAILED/SKIPPED: $pkg (testing)"
        return 1
    fi
}

# Update package database
log_msg "=== Updating package database ==="
apk update >> "$LOG_FILE" 2>&1
apk upgrade >> "$LOG_FILE" 2>&1

# Extra tool support
log_msg "=== Installing Extra tools support ==="
install_pkg android-tools
install_pkg rng-tools
install_pkg commons-daemon
install_pkg libcap
install_pkg libcap-utils
install_pkg jsvc
install_pkg grep
install_pkg kmod
install_pkg cronie
install_pkg kbd
install_pkg libcrypto3
install_pkg cryptsetup
install_pkg acl
install_pkg attr
install_pkg libmount
install_pkg pcre2
install_pkg openssl
install_pkg libblkid
install_pkg mdevd
install_pkg mdev-conf
install_pkg wine
install_pkg steam-devices

# Development build Tools
log_msg "=== Installing Development Tools and Build Dependencies ==="
install_pkg build-base        # Meta-package with gcc, make, etc.
install_pkg gcc
install_pkg g++
install_pkg make
install_pkg cmake
install_pkg musl-dev
install_pkg linux-headers
install_pkg opencl-headers

# Core System & Device Management (for all block devices)
log_msg "=== Installing Core System Packages ==="
install_pkg eudev
install_pkg eudev-libs
install_pkg util-linux
install_pkg coreutils
install_pkg parted
install_pkg gptfdisk        # Replaces gdisk - GPT partition tool
install_pkg mmc-utils
install_pkg busybox-extras

# Serial Communication (8 ttyGS + 2 ttyS devices)
log_msg "=== Installing Serial Communication Packages ==="
install_pkg setserial
install_pkg minicom
install_pkg screen
install_pkg socat
install_pkg agetty          # getty is part of util-linux
log_msg "Note: getty functionality provided by agetty"

# USB Support (bus/usb devices)
log_msg "=== Installing USB Support Packages ==="
install_pkg usbutils
install_pkg libusb
install_pkg libusb-dev
install_pkg usb-modeswitch
log_msg "Note: usb-modeswitch includes necessary data files"
install_pkg udisks2
install_pkg udisks2-dev

# Audio/ALSA Support (31 ALSA devices in /dev/snd/)
log_msg "=== Installing Audio Support Packages ==="
install_pkg alsa-utils
install_pkg alsa-lib
install_pkg alsa-lib-dev
install_pkg alsa-ucm-conf
install_pkg pulseaudio
install_pkg pulseaudio-alsa
install_pkg pipewire
install_pkg pipewire-alsa
install_pkg pipewire-pulse
install_pkg alsa-plugins-pulse
install_pkg alsa-plugins-jack
install_pkg pavucontrol      # PulseAudio volume control GUI
install_pkg jack               # JACK audio connection kit

# Video/Camera Support
log_msg "=== Installing Video Support Packages ==="
install_pkg v4l-utils
install_pkg v4l-utils-dev
install_pkg v4l-utils-libs
log_msg "Note: libv4l and libv4l-dev are included in v4l-utils packages"
install_pkg ffmpeg
install_pkg ffmpeg-libs
install_pkg libjpeg
install_pkg libvpx

# Graphics/DRM Support with Panfrost for ARM Mali GPU
log_msg "=== Installing Graphics Support Packages ==="
install_pkg libdrm
install_pkg libdrm-dev
install_pkg libdrm-tests
install_pkg mesa
install_pkg mesa-dev
install_pkg mesa-dri-gallium
install_pkg mesa-gl
install_pkg mesa-gles
install_pkg mesa-egl
install_pkg mesa-gbm
install_pkg mesa-utils
install_pkg mesa-demos
install_pkg kmscube

# Panfrost driver for ARM Mali GPU
log_msg "=== Installing Panfrost Driver for ARM Mali GPU ==="
install_pkg mesa-vulkan-panfrost
log_msg "Panfrost vulkan driver installed for ARM Mali GPU support"

# Vulkan support
log_msg "=== Installing Vulkan Support ==="
install_pkg mesa-vulkan-layers
install_pkg vulkan-loader
install_pkg vulkan-tools
install_pkg mesa-vulkan-swrast

# SDL2 for graphics applications
install_pkg sdl2
install_pkg sdl2-dev

# X.org and Display Drivers
log_msg "=== Installing X.org Server and Display Drivers ==="
install_pkg xorg-server
install_pkg xvfb
install_pkg virglrenderer
install_pkg xf86-video-modesetting    # Modern KMS-based driver / video-vesa not available
install_pkg xf86-input-evdev
install_pkg xf86-input-libinput
install_pkg xinit
install_pkg xrandr
install_pkg xset
install_pkg xprop
install_pkg xdpyinfo
log_msg "=== Installing X11 Utilities ==="
install_pkg xauth
install_pkg xhost
install_pkg xmodmap
install_pkg setxkbmap
install_pkg xdotool
install_testing_pkg wmctrl     # Window manager control utility (from testing)
install_pkg conky              # System monitor

# Wayland
log_msg "=== Wayland ==="
install_pkg eudev
install_pkg mkrundir
install_pkg elogind
install_pkg cage
install_pkg Wayland
log_msg "=== Installing sway ==="
install_pkg sway
install_pkg foot
install_pkg wmenu
install_pkg swaylock swaylockd
install_pkg swaybg
install_pkg grim
install_pkg wl-clipboard
install_pkg i3status
install_pkg swayidle

# Weston
log_msg "=== Weston ==="
install_pkg weston
install_pkg weston-backend-drm
install_pkg seatd
install_pkg weston-backend-wayland
install_pkg weston-shell-desktop
install_pkg weston-terminal
install_pkg font-dejavu

# Fluxbox Window Manager and Related Packages
log_msg "=== Installing Fluxbox Window Manager ==="
install_pkg fluxbox
install_pkg xterm              # Terminal emulator
install_pkg font-terminus      # Console font
install_pkg ttf-dejavu         # TrueType fonts
install_pkg ttf-liberation     # Liberation fonts
install_pkg font-noto          # Noto fonts for Unicode support

# Network Configuration (for ppp, tun devices)
log_msg "=== Installing Network Packages ==="
install_pkg iproute2
install_pkg net-tools
install_pkg wireless-tools
install_pkg iw
install_pkg wpa_supplicant
install_pkg hostapd
install_pkg dhcpcd            # dhcp replaced by dhcpcd
install_pkg ppp
install_pkg openssh-client
install_pkg curl
install_pkg wget

# Cellular/Modem Support (UNISOC LTE devices: 47 devices)
log_msg "=== Installing Modem/Cellular Packages ==="
install_pkg modemmanager
install_pkg libqmi
install_pkg libmbim
install_pkg networkmanager
install_pkg networkmanager-wifi
install_pkg networkmanager-wwan
install_pkg mobile-broadband-provider-info

# Input Device Support (6 input event devices)
log_msg "=== Installing Input Device Packages ==="
install_pkg libinput
install_pkg libinput-dev
install_pkg evtest
log_msg "Note: input-utils not available, evtest provides similar functionality"
install_pkg libevdev
install_pkg libevdev-dev
install_pkg xf86-input-libinput

# Sensor/IIO Support (2 iio:device devices)
log_msg "=== Installing Sensor Packages ==="
log_msg "Attempting to install libiio from testing repository..."
install_testing_pkg libiio
install_testing_pkg libiio-dev
install_pkg iio-sensor-proxy
install_pkg lm-sensors
install_pkg i2c-tools

# GPIO Support (6 gpiochip devices)
log_msg "=== Installing GPIO Packages ==="
install_pkg libgpiod
install_pkg libgpiod-dev
log_msg "Note: gpiod tools are included in libgpiod package"
install_pkg python3
install_pkg python3-dev
install_pkg py3-pip

# I2C Support (6 i2c-* bus devices)
log_msg "=== Installing I2C Packages ==="
install_pkg i2c-tools
install_pkg py3-smbus

# SPI Support
log_msg "=== Installing SPI Packages ==="
install_pkg spi-tools
log_msg "Installing spidev via pip..."
pip3 install --break-system-packages spidev >> "$LOG_FILE" 2>&1 &&     log_msg "  ✓ SUCCESS: spidev (via pip)" ||     log_msg "  ⚠ FAILED: spidev (via pip)"

# System Utilities
log_msg "=== Installing System Utilities ==="
install_pkg rng-tools
install_pkg haveged
log_msg "Attempting to install watchdog from testing..."
install_testing_pkg watchdog
log_msg "Attempting to install device tree compiler (dtc) from community..."
apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community dtc >> "$LOG_FILE" 2>&1 &&     log_msg "  ✓ SUCCESS: dtc" ||     log_msg "  ⚠ SKIPPED: dtc"
install_pkg dmidecode
install_pkg htop
install_pkg nano
install_pkg vim
install_pkg dbus
install_pkg dbus-x11
install_pkg polkit
install_pkg sudo
install_pkg upower
install_pkg tlp

# RTC Support (/dev/rtc0)
log_msg "=== RTC Support ==="
log_msg "Note: hwclock is provided by util-linux (already installed)"

# Bluetooth utilities and tools
log_msg "=== Installing Bluetooth ==="
install_pkg bluez
install_pkg bluez-deprecated    # Legacy Bluetooth tools
install_pkg bluez-obexd         # OBEX file transfer
install_pkg bluez-meshctl       # Bluetooth Mesh
# Bluetooth audio support
install_pkg bluez-alsa          # ALSA Bluetooth audio
# Serial port profile (for ttyBT devices)
install_pkg openobex            # Wireless Binary HTTP protocol

# File Manager and Desktop Utilities
log_msg "=== Installing Desktop Applications ==="
install_pkg pcmanfm           # Lightweight file manager
install_pkg feh               # Image viewer
install_pkg vlc               # Video player

# Flatpak Support
log_msg "=== Installing Flatpak Support ==="
install_pkg flatpak
install_pkg xdg-desktop-portal
install_pkg xdg-desktop-portal-gtk
install_pkg xdg-utils

# Enable FUSE support for Flatpak
log_msg "Enabling FUSE support for Flatpak..."
rc-update add fuse boot >> "$LOG_FILE" 2>&1 && \
    log_msg "  ✓ FUSE service enabled" || \
    log_msg "  ⚠ FUSE service enable skipped (may already be enabled)"

# Compression and Archive Tools
log_msg "=== Installing Archive Tools ==="
install_pkg zip
install_pkg unzip
install_pkg tar
install_pkg gzip
install_pkg bzip2
install_pkg xz

log_msg "=== Package Installation Completed at $(date) ==="
log_msg "Check $LOG_FILE for detailed installation log"

# Display summary
echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
apk list --installed | wc -l | xargs echo "Total packages installed:"
echo ""
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""

